// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IdentityRegistry} from "../src/registry/IdentityRegistry.sol";
import {AssetRegistry} from "../src/registry/AssetRegistry.sol";
import {CustodianAttestationSource} from "../src/registry/CustodianAttestationSource.sol";
import {IAssetRegistry} from "../src/registry/interfaces/IAssetRegistry.sol";
import {IReserveAttestationSource} from "../src/registry/interfaces/IReserveAttestationSource.sol";
import {Token} from "../src/tokens/Token.sol";

/**
 * @title OnboardAsset
 * @notice T6.1a stage 2: onboards one asset lot from a declarative input file and the
 *         verified-attestation file written by stage 1 (`scripts/onboard/run.mjs`).
 * @dev Clause 1 (the custodian's ML-DSA-65 signature) is checked off-chain before this runs
 *      (ADR 0027); this script never runs a subprocess. Every step reads on-chain state first,
 *      so a re-run continues where an earlier one stopped (AC-6). Pre-flight failures revert
 *      before any transaction (AC-7). It never deploys, transfers, freezes or pauses.
 *
 *      Inputs: `ONBOARD_INPUT` and `ONBOARD_VERIFIED` (paths), `M3_AGENT_PK`, and
 *      `M3_OWNER_PK` (used on anvil only, for `setTokenFor`). Addresses come from
 *      `deployments/<chainid>.json` and nowhere else.
 */
contract OnboardAsset is Script {
    uint256 internal constant ANVIL_CHAIN_ID = 31337;
    uint256 internal constant FINENESS_SCALE = 10000;
    uint256 internal constant VALUATION_DRIFT_WARNING = 1 hours;

    struct Deployed {
        IdentityRegistry identityRegistry;
        AssetRegistry assetRegistry;
        CustodianAttestationSource attestationSource;
        Token token;
    }

    struct Keys {
        uint256 agentPk;
        uint256 ownerPk; // 0 = the owner is a multisig; only used on anvil
    }

    struct Input {
        string slug;
        bytes32 assetId;
        string description;
        uint256 grossWeight;
        uint16 fineness;
        string valuationSource;
        string currency;
        uint256 unitValue;
        uint64 valuationTs;
        string custodianId;
        uint256 intendedSupply;
        uint256 attestationCount;
        address providerWallet;
        address token;
    }

    struct Verified {
        uint256 chainId;
        bytes32 assetId;
        uint256 reserve;
        uint64 seq;
        uint64 valuationTs;
        bytes32 envelopeHash;
    }

    enum Outcome {
        Minted,
        AlreadyLive,
        WaitingForOwner
    }

    // Pre-flight (spec §3 P), all before any transaction.
    error TooManyAttestationsForMs1(uint256 count);
    error BadChecksumAddress(string field, string given);
    error FixtureSourceOutsideTest(string source);
    error SupplyWeightMismatch(uint256 intended, uint256 derived);
    error TokenMismatch(address input, address deployed);
    error ProviderNotVerified(address wallet);
    error VerifiedFileForOtherAsset(bytes32 input, bytes32 verified);
    error AttestationForOtherChain(uint256 expected, uint256 got);
    // State branch and binding.
    error AssetIsFrozen(bytes32 assetId);
    error PartialSupply(uint256 onChain, uint256 intended);
    error TokenAlreadyBoundElsewhere(bytes32 assetId, address bound);
    error TokenBoundToOtherAsset(address token, bytes32 otherAssetId);
    // Admission and mint, carrying the operator sentence (T6 spec §3.4).
    error AdmitRejected(bytes reason, string sentence);
    error MintPreflightFailed(string condition);
    error MintRefused(string sentence);

    // ------------------------------------------------------------------
    // Entry point
    // ------------------------------------------------------------------

    function run() external returns (Outcome outcome) {
        string memory dep =
            vm.readFile(string.concat(vm.projectRoot(), "/deployments/", vm.toString(block.chainid), ".json"));
        Deployed memory d = Deployed({
            identityRegistry: IdentityRegistry(vm.parseJsonAddress(dep, ".identityRegistry")),
            assetRegistry: AssetRegistry(vm.parseJsonAddress(dep, ".assetRegistry")),
            attestationSource: CustodianAttestationSource(vm.parseJsonAddress(dep, ".attestationSource")),
            token: Token(vm.parseJsonAddress(dep, ".token"))
        });
        Keys memory k = Keys({agentPk: vm.envUint("M3_AGENT_PK"), ownerPk: vm.envOr("M3_OWNER_PK", uint256(0))});
        outcome =
            onboard(vm.readFile(vm.envString("ONBOARD_INPUT")), vm.readFile(vm.envString("ONBOARD_VERIFIED")), d, k);
        if (outcome == Outcome.WaitingForOwner) console2.log("ONBOARD_STATUS=WAITING_FOR_OWNER");
        else if (outcome == Outcome.AlreadyLive) console2.log("ONBOARD_STATUS=ALREADY_LIVE");
        else console2.log("ONBOARD_STATUS=MINTED");
    }

    /// @notice The whole of spec §3 (P, S, B, A, M, R) for one input.
    function onboard(string memory inputJson, string memory verifiedJson, Deployed memory d, Keys memory k)
        public
        returns (Outcome)
    {
        Input memory input = parseInput(inputJson);
        Verified memory v = parseVerified(verifiedJson);
        _preflight(input, v, d);

        // S — state branch.
        IAssetRegistry.AssetState s = d.assetRegistry.stateOf(input.assetId);
        if (s == IAssetRegistry.AssetState.FROZEN) {
            console2.log("This asset is frozen; an operator must resolve it.");
            revert AssetIsFrozen(input.assetId);
        }
        if (s == IAssetRegistry.AssetState.LIVE) {
            uint256 supply = d.token.totalSupply();
            if (supply == input.intendedSupply) {
                console2.log("Asset is already live; nothing to do.");
                _receipt(input, d);
                return Outcome.AlreadyLive;
            }
            if (supply != 0) revert PartialSupply(supply, input.intendedSupply);
            // LIVE with nothing minted: an earlier run stopped after admit. Go to the mint.
        }
        if (s == IAssetRegistry.AssetState.UNREGISTERED) {
            vm.broadcast(k.agentPk);
            d.assetRegistry.register(input.assetId, metadataHash(input), input.slug);
            s = IAssetRegistry.AssetState.PENDING;
        }

        // B — binding.
        if (!_bind(input, d, k)) return Outcome.WaitingForOwner;

        // A — attest and admit (PENDING only).
        if (s == IAssetRegistry.AssetState.PENDING) _attestAndAdmit(input, v, d, k);

        // M — mint.
        _mint(input, d, k);
        _receipt(input, d);
        return Outcome.Minted;
    }

    // ------------------------------------------------------------------
    // Parsing and the metadata hash
    // ------------------------------------------------------------------

    /// @notice Reads the T6.0 input file; rejects a mixed-case address that is not EIP-55 (AC-20).
    function parseInput(string memory json) public view returns (Input memory i) {
        i.slug = vm.parseJsonString(json, ".assetId");
        i.assetId = keccak256(bytes(i.slug));
        i.description = vm.parseJsonString(json, ".description");
        i.grossWeight = vm.parseJsonUint(json, ".grossWeight");
        i.fineness = uint16(vm.parseJsonUint(json, ".fineness"));
        i.valuationSource = vm.parseJsonString(json, ".valuationBasis.source");
        i.currency = vm.parseJsonString(json, ".valuationBasis.currency");
        i.unitValue = vm.parseJsonUint(json, ".valuationBasis.unitValue");
        i.valuationTs = uint64(vm.parseJsonUint(json, ".valuationBasis.valuationTs"));
        i.custodianId = vm.parseJsonString(json, ".custodianId");
        i.intendedSupply = vm.parseJsonUint(json, ".intendedSupply");
        while (vm.keyExistsJson(json, string.concat(".attestations[", vm.toString(i.attestationCount), "]"))) {
            ++i.attestationCount;
        }
        i.providerWallet = _checkedAddress(json, "providerWallet");
        i.token = _checkedAddress(json, "token");
    }

    /// @notice Reads the stage-1 verified file (`.onboard/<slug>.verified.json`).
    function parseVerified(string memory json) public pure returns (Verified memory v) {
        v.chainId = vm.parseJsonUint(json, ".chainId");
        v.assetId = vm.parseJsonBytes32(json, ".assetId");
        v.reserve = vm.parseJsonUint(json, ".reserve");
        v.seq = uint64(vm.parseJsonUint(json, ".seq"));
        v.valuationTs = uint64(vm.parseJsonUint(json, ".valuationTs"));
        v.envelopeHash = vm.parseJsonBytes32(json, ".envelopeHash");
    }

    /// @notice The canonical eight-field recipe (T6.1a spec §3, `METADATA_HASH_FIELDS`).
    function metadataHash(Input memory i) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                i.slug,
                i.description,
                i.grossWeight,
                i.fineness,
                i.valuationSource,
                i.currency,
                i.unitValue,
                i.custodianId
            )
        );
    }

    // ------------------------------------------------------------------
    // Steps
    // ------------------------------------------------------------------

    function _preflight(Input memory i, Verified memory v, Deployed memory d) internal view {
        if (i.attestationCount != 1) revert TooManyAttestationsForMs1(i.attestationCount);
        if (_startsWith(i.valuationSource, "FIXTURE") && block.chainid != ANVIL_CHAIN_ID) {
            revert FixtureSourceOutsideTest(i.valuationSource);
        }
        uint256 derived = i.grossWeight * i.fineness / FINENESS_SCALE;
        if (i.grossWeight * i.fineness != i.intendedSupply * FINENESS_SCALE) {
            revert SupplyWeightMismatch(i.intendedSupply, derived);
        }
        if (i.token != address(d.token)) revert TokenMismatch(i.token, address(d.token));
        if (v.chainId != block.chainid) revert AttestationForOtherChain(block.chainid, v.chainId);
        if (v.assetId != i.assetId) revert VerifiedFileForOtherAsset(i.assetId, v.assetId);
        if (!d.identityRegistry.isVerified(i.providerWallet)) {
            console2.log(
                string.concat(
                    "The provider wallet ",
                    vm.toString(i.providerWallet),
                    unicode" is not KYC-verified. Run VerifyWallet first (How to Run §6)."
                )
            );
            revert ProviderNotVerified(i.providerWallet);
        }
        console2.log("valuationTs in the input file:     ", i.valuationTs);
        console2.log("valuationTs in the signed envelope:", v.valuationTs);
        uint64 drift = i.valuationTs > v.valuationTs ? i.valuationTs - v.valuationTs : v.valuationTs - i.valuationTs;
        if (drift > VALUATION_DRIFT_WARNING) {
            console2.log(
                "WARNING: they differ by more than 1 hour. The chain checks the envelope's timestamp, not the input's."
            );
        }
    }

    /// @return bound false when the owner multisig still has to call `setTokenFor`.
    function _bind(Input memory i, Deployed memory d, Keys memory k) internal returns (bool bound) {
        address current = d.assetRegistry.tokenOf(i.assetId);
        if (current == address(d.token)) return true;
        if (current != address(0)) revert TokenAlreadyBoundElsewhere(i.assetId, current);
        bytes32 other = d.assetRegistry.assetOfToken(address(d.token));
        if (other != bytes32(0)) revert TokenBoundToOtherAsset(address(d.token), other);

        if (block.chainid == ANVIL_CHAIN_ID && k.ownerPk != 0) {
            vm.broadcast(k.ownerPk);
            d.assetRegistry.setTokenFor(i.assetId, address(d.token));
            return true;
        }
        console2.log("OWNER CALL for the multisig (to / data):");
        console2.log(address(d.assetRegistry));
        console2.logBytes(abi.encodeCall(AssetRegistry.setTokenFor, (i.assetId, address(d.token))));
        console2.log("Waiting for the owner multisig to bind the token. Re-run this command after it confirms.");
        return false;
    }

    function _attestAndAdmit(Input memory i, Verified memory v, Deployed memory d, Keys memory k) internal {
        CustodianAttestationSource src = d.attestationSource;
        uint64 onSeq = src.hasAttestation(i.assetId) ? src.latest(i.assetId).seq : 0;
        if (onSeq < v.seq) {
            vm.broadcast(k.agentPk);
            src.submitAttestation(
                IReserveAttestationSource.ReserveAttestation(i.assetId, v.reserve, v.seq, v.valuationTs), v.envelopeHash
            );
        } else if (onSeq != v.seq || src.envelopeHashOf(i.assetId) != v.envelopeHash) {
            // The source already holds this sequence or a newer one, from another envelope.
            bytes memory reason = abi.encodeWithSelector(IAssetRegistry.StaleSequence.selector, v.seq, onSeq);
            _rejectAdmit(
                reason,
                string.concat(
                    describeAdmitError(reason),
                    " The source already holds a newer attestation (seq ",
                    vm.toString(onSeq),
                    ")."
                )
            );
        }

        // Clauses 2-4 checked here first, so the failing one is named before anything is sent.
        bytes memory pre = _admitPrecheck(i, v, d);
        if (pre.length != 0) _rejectAdmit(pre, describeAdmitError(pre));

        vm.broadcast(k.agentPk);
        try d.assetRegistry.admit(i.assetId, i.intendedSupply) {}
        catch (bytes memory err) {
            _rejectAdmit(err, describeAdmitError(err));
        }
    }

    /// @dev Mirrors `AssetRegistry.admit` clauses 2-4 for a PENDING asset; empty when they pass.
    function _admitPrecheck(Input memory i, Verified memory v, Deployed memory d) internal view returns (bytes memory) {
        uint64 last = d.assetRegistry.lastSequenceOf(i.assetId);
        if (v.seq <= last) return abi.encodeWithSelector(IAssetRegistry.StaleSequence.selector, v.seq, last);
        if (v.reserve < i.intendedSupply) {
            return abi.encodeWithSelector(IAssetRegistry.ReserveTooLow.selector, v.reserve, i.intendedSupply);
        }
        if (v.valuationTs > block.timestamp) {
            return abi.encodeWithSelector(IAssetRegistry.ValuationInFuture.selector, v.valuationTs, block.timestamp);
        }
        uint64 window = d.assetRegistry.valuationWindowOf(i.assetId);
        if (window == 0 || block.timestamp - v.valuationTs > window) {
            return abi.encodeWithSelector(IAssetRegistry.ValuationStale.selector, v.valuationTs, window);
        }
        return "";
    }

    function _mint(Input memory i, Deployed memory d, Keys memory k) internal {
        AssetRegistry r = d.assetRegistry;
        if (!r.isLive(i.assetId)) revert MintPreflightFailed("the asset is not LIVE");
        uint64 ts = r.valuationTsOf(i.assetId);
        uint64 window = r.valuationWindowOf(i.assetId);
        if (window == 0 || ts > block.timestamp || block.timestamp - ts > window) {
            revert MintPreflightFailed(string.concat(
                    "the admitted valuation is not fresh (valuationTs ",
                    vm.toString(ts),
                    ", window ",
                    _duration(window),
                    "); submit a fresh attestation"
                ));
        }
        uint256 supply = d.token.totalSupply();
        uint256 reserve = r.reserveOf(i.assetId);
        if (supply > reserve || i.intendedSupply > reserve - supply) {
            revert MintPreflightFailed(string.concat(
                    "totalSupply + intendedSupply (",
                    vm.toString(supply),
                    " + ",
                    vm.toString(i.intendedSupply),
                    ") exceeds reserveOf (",
                    vm.toString(reserve),
                    ")"
                ));
        }

        vm.broadcast(k.agentPk);
        try d.token.mint(i.providerWallet, i.intendedSupply) {}
        catch (bytes memory err) {
            if (bytes4(err) == Token.TransferNotCompliant.selector) {
                revert MintRefused("Compliance refused the mint; the pre-flight passed, so the state changed between the check and the send. Re-run.");
            }
            assembly {
                revert(add(err, 32), mload(err))
            }
        }
    }

    function _receipt(Input memory i, Deployed memory d) internal view {
        AssetRegistry r = d.assetRegistry;
        string[4] memory names = ["UNREGISTERED", "PENDING", "LIVE", "FROZEN"];
        console2.log("---- RECEIPT ----");
        console2.log("asset      ", i.slug);
        console2.logBytes32(i.assetId);
        console2.log("state      ", names[uint8(r.stateOf(i.assetId))]);
        console2.log("reserveOf  ", r.reserveOf(i.assetId));
        console2.log("totalSupply", d.token.totalSupply());
        console2.log("seq        ", r.lastSequenceOf(i.assetId));
        console2.log("valuationTs", r.valuationTsOf(i.assetId));
        console2.log("token      ", address(d.token));
        console2.log("provider   ", i.providerWallet);
        console2.log("balance    ", d.token.balanceOf(i.providerWallet));
        console2.log("envelope   ");
        console2.logBytes32(d.attestationSource.envelopeHashOf(i.assetId));
        console2.log("units: intendedSupply and reserve in FINE grams x 1e18; unitValue per FINE gram (ADR 0020)");
        if (r.metadataHashOf(i.assetId) != metadataHash(i)) {
            console2.log("metadata on chain differs from this input");
        }
        if (_startsWith(i.valuationSource, "FIXTURE")) {
            console2.log(unicode"MS1 FIXTURE ATTESTATION — NOT INDEPENDENTLY VERIFIED");
        }
    }

    // ------------------------------------------------------------------
    // Operator sentences (T6 spec §3.4, T6.1a spec §3 A)
    // ------------------------------------------------------------------

    /// @notice Turns an admission revert into the sentence the operator is shown.
    function describeAdmitError(bytes memory err) public view returns (string memory) {
        if (err.length < 4) return string.concat("Admission reverted with no reason; unexpected; report it.");
        bytes4 sel = bytes4(err);
        bytes memory args = _args(err);
        if (sel == IAssetRegistry.StaleSequence.selector) {
            (uint64 seq, uint64 last) = abi.decode(args, (uint64, uint64));
            return string.concat(
                "This attestation (seq ",
                vm.toString(seq),
                ") is older than or equal to the last one accepted (seq ",
                vm.toString(last),
                ")."
            );
        }
        if (sel == IAssetRegistry.ReserveTooLow.selector) {
            (uint256 reserve, uint256 intended) = abi.decode(args, (uint256, uint256));
            return string.concat(
                "The attested reserve (",
                vm.toString(reserve),
                ") is less than the supply you asked to mint (",
                vm.toString(intended),
                ")."
            );
        }
        if (sel == IAssetRegistry.ValuationStale.selector) {
            (uint64 ts, uint64 window) = abi.decode(args, (uint64, uint64));
            uint256 age = block.timestamp > ts ? block.timestamp - ts : 0;
            return string.concat(
                "This valuation is ",
                vm.toString(age / 1 hours),
                " hours old; the limit is ",
                _duration(window),
                ". This is the timestamp inside the signed envelope; editing the input file will not change it."
            );
        }
        if (sel == IAssetRegistry.ValuationInFuture.selector) {
            (uint64 ts, uint64 nowTs) = abi.decode(args, (uint64, uint64));
            return string.concat(
                "This valuation is dated ",
                vm.toString(ts - nowTs),
                " seconds in the future (envelope valuationTs ",
                vm.toString(ts),
                ", chain time ",
                vm.toString(nowTs),
                "). This is the timestamp inside the signed envelope; editing the input file will not change it."
            );
        }
        return string.concat("Admission reverted with ", vm.toString(err), "; unexpected; report it.");
    }

    function _rejectAdmit(bytes memory reason, string memory sentence) internal pure {
        console2.log(sentence);
        revert AdmitRejected(reason, sentence);
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    function _checkedAddress(string memory json, string memory field) internal pure returns (address a) {
        string memory given = vm.parseJsonString(json, string.concat(".", field));
        a = vm.parseAddress(given);
        if (!_isLowercase(given) && keccak256(bytes(given)) != keccak256(bytes(vm.toString(a)))) {
            revert BadChecksumAddress(field, given);
        }
    }

    function _isLowercase(string memory s) internal pure returns (bool) {
        bytes memory b = bytes(s);
        for (uint256 j = 2; j < b.length; ++j) {
            if (b[j] >= "A" && b[j] <= "F") return false;
        }
        return true;
    }

    function _startsWith(string memory s, string memory prefix) internal pure returns (bool) {
        bytes memory b = bytes(s);
        bytes memory p = bytes(prefix);
        if (b.length < p.length) return false;
        for (uint256 j; j < p.length; ++j) {
            if (b[j] != p[j]) return false;
        }
        return true;
    }

    function _duration(uint256 secs) internal pure returns (string memory) {
        if (secs != 0 && secs % 1 hours == 0) return string.concat(vm.toString(secs / 1 hours), " hours");
        return string.concat(vm.toString(secs), " seconds");
    }

    function _args(bytes memory err) internal pure returns (bytes memory args) {
        args = new bytes(err.length - 4);
        for (uint256 j; j < args.length; ++j) {
            args[j] = err[j + 4];
        }
    }
}
