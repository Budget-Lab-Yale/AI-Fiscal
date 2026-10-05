"""Build the v2 methodology plan (.docx) from its markdown source.

    python docs/plans/build_methodology_plan.py [output.docx]

Source: docs/plans/v2_methodology_plan_source.md (+ fig3_v2_transmission.png).
Output defaults to docs/AI-Fiscal-V2-Methodology-Plan-<date>.docx, which is
gitignored like the repo's other Word files. Requires pandoc on PATH.

Steps: pandoc's default reference.docx is restyled (Yale-blue headings,
Arial headings / Georgia body); pandoc writes the document with native Word
equations; the png content type pandoc omits is added so the file passes
strict OOXML validation.
"""
import datetime
import pathlib
import re
import subprocess
import sys
import tempfile
import zipfile

HERE = pathlib.Path(__file__).resolve().parent
SOURCE = HERE / "v2_methodology_plan_source.md"
YALE_BLUE = "00356B"


def restyled_reference(workdir):
    ref = workdir / "reference.docx"
    with open(ref, "wb") as fh:
        subprocess.run(["pandoc", "--print-default-data-file", "reference.docx"],
                       stdout=fh, check=True)
    out = workdir / "reference_tbl.docx"
    with zipfile.ZipFile(ref) as zin, zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == "word/styles.xml":
                styles = data.decode("utf-8")
                styles = re.sub(r'<w:color\s+w:val="[0-9A-F]{6}"\s+w:themeColor="accent1"[^/]*/>',
                                '<w:color w:val="%s"/>' % YALE_BLUE, styles, flags=re.S)
                styles = (styles.replace('w:asciiTheme="majorHAnsi"', 'w:ascii="Arial"')
                                .replace('w:hAnsiTheme="majorHAnsi"', 'w:hAnsi="Arial"')
                                .replace('w:asciiTheme="minorHAnsi"', 'w:ascii="Georgia"')
                                .replace('w:hAnsiTheme="minorHAnsi"', 'w:hAnsi="Georgia"'))
                data = styles.encode("utf-8")
            zout.writestr(item, data)
    return out


def declare_png(docx):
    tmp = docx.with_suffix(".tmp.docx")
    with zipfile.ZipFile(docx) as zin, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == "[Content_Types].xml":
                types = data.decode("utf-8")
                if 'Extension="png"' not in types:
                    types = types.replace('<Default Extension="xml"',
                                          '<Default Extension="png" ContentType="image/png"/>'
                                          '<Default Extension="xml"', 1)
                data = types.encode("utf-8")
            zout.writestr(item, data)
    tmp.replace(docx)


def main():
    stamp = datetime.date.today().isoformat()
    default = HERE.parent / ("AI-Fiscal-V2-Methodology-Plan-%s.docx" % stamp)
    output = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else default
    with tempfile.TemporaryDirectory() as tmp:
        reference = restyled_reference(pathlib.Path(tmp))
        subprocess.run(["pandoc", str(SOURCE), "-o", str(output),
                        "--reference-doc", str(reference),
                        "--resource-path", str(HERE)], check=True)
    declare_png(output)
    print("wrote", output)


if __name__ == "__main__":
    main()
