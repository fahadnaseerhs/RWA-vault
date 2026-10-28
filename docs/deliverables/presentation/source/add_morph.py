"""Add a Morph transition (fade fallback for Google Slides) to every slide of a .pptx."""
import re, shutil, sys, zipfile

TRANSITION = (
    '<mc:AlternateContent xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006">'
    '<mc:Choice xmlns:p159="http://schemas.microsoft.com/office/powerpoint/2015/09/main" Requires="p159">'
    '<p:transition xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main" spd="fast" p14:dur="600">'
    '<p159:morph option="byObject"/></p:transition></mc:Choice>'
    '<mc:Fallback><p:transition spd="fast"><p:fade/></p:transition></mc:Fallback>'
    '</mc:AlternateContent>'
)

src, dst = sys.argv[1], sys.argv[2]
tmp = dst + ".tmp"
with zipfile.ZipFile(src) as zin, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        data = zin.read(item.filename)
        if re.fullmatch(r"ppt/slides/slide\d+\.xml", item.filename):
            xml = data.decode("utf-8")
            if "p159:morph" not in xml:
                if "</p:clrMapOvr>" in xml:
                    xml = xml.replace("</p:clrMapOvr>", "</p:clrMapOvr>" + TRANSITION, 1)
                else:
                    xml = xml.replace("</p:cSld>", "</p:cSld>" + TRANSITION, 1)
            data = xml.encode("utf-8")
        zout.writestr(item, data)
shutil.move(tmp, dst)
print("morph added ->", dst)
