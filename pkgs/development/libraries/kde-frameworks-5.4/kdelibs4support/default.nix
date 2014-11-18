{ mkDerivation, docbook_xml_dtd_45, networkmanager, xlibs }:

mkDerivation {
  buildInputs = [ networkmanager xlibs.libSM ];
  cmakeFlags = [
    "-DDocBookXML4_DTD_DIR=${docbook_xml_dtd_45}/xml/dtd/docbook"
    "-DDocBookXML4_DTD_VERSION=4.5"
  ];
}
