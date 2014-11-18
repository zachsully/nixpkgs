{ mkDerivation, docbook_xml_dtd_45, docbook5_xsl, karchive, ki18n }:

mkDerivation {
  cmakeFlags = [
    "-DDocBookXML4_DTD_DIR=${docbook_xml_dtd_45}/xml/dtd/docbook"
    "-DDocBookXML4_DTD_VERSION=4.5"
    "-DDocBookXSL_DIR=${docbook5_xsl}/xml/xsl/docbook"
  ];
  patches = [
    ./kdoctools-no-find-docbook-xml.patch
  ];
}
