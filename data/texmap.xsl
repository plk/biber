<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:bcf="https://sourceforge.net/projects/biblatex"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="xs xsl bcf"
                version="1.0">

  <!-- Use strict Doctype otherwise IE7 is too stupid to do tables correctly -->
  <xsl:output method="html" 
              media-type="text/html" 
              doctype-public="-//W3C//DTD XHTML 1.0 Strict//EN"
              doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"
              indent="yes"
              encoding="UTF-8"/>

  <xsl:template match="/">
    <html>
      <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
        <title>Biber UTF-8 <xsl:text disable-output-escaping="yes">&amp;harr;</xsl:text> LaTeX macro decoding/encoding map</title>
        <style type="text/css">
          h2,h3,h4 {
            font-family: Arial,sans-serif;
          }
          .key {
            font-size: 70%;
            padding-top: 2ex;
          }
          .macro, .hex {
            font-family: "Courier New", Courier, monospace ;
          }
          @font-face {
            font-family: "Cyberbit";
            src: url(http://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/testfiles/Cyberbit.ttf) format("truetype");
          }
          .utf8 {
            font-family: Cyberbit;
          }
          .full {
            background-color: #E6FFE6;
          }
          .preferred {
            color: #FF0000;
            font-family: "Courier New", Courier, monospace ;
          }
          ul {
            list-style-type: none;
            margin-left: 0;
            margin-right: 0;
            margin-top: 0;
            margin-bottom: 0;
            padding-left: 0;
            padding-top: 0;
            padding-bottom: 0;
            padding-right: 0;
          }
          table {
            border-width: 1px;
            border-spacing: 2px;
            border-style: hidden;
            border-color: gray;
            border-collapse: collapse;
            background-color: white;
          }
          table thead {
            background-color: #FAF0E6;
            text-align: center;
          }
          table td {
            wrap: soft;
            vertical-align: text-top;
            line-height: 1;
            padding: 0px 5px 0px 5px;
            border-width: 1px;
            border-style: inset;
            border-color: gray;
          }
        </style>
      </head>
      <body>
        <h2><tt>Biber</tt> UTF-8  <xsl:text disable-output-escaping="yes">&amp;harr;</xsl:text> LaTeX macro decoding/encoding map</h2>
          <div class="key"><u>Key</u>
          <ul>
            <li><span class="full">Mapping only in &quot;full&quot; mapping set</span></li>
            <li><span class="preferred">In encoding mapping (UTF-8 <xsl:text disable-output-escaping="yes">&amp;rarr;</xsl:text> LaTeX macros), when there are multiple possible mappings, red highlighted macro is the preferred mapping</span></li>
          </ul>
          </div>
        <hr/>
        <h3>Excluded from encoding (ignore LaTeX special chars)</h3>
        <table>
          <thead>
            <tr><td>Character</td></tr>
          </thead>
          <tbody>
            <xsl:for-each select="/texmap/encode_exclude/char">
              <tr>
                <td><span class="macro"><xsl:value-of select="./text()"/></span></td>
              </tr>
            </xsl:for-each>              
          </tbody>
        </table>
        <hr/>
        <h3>Accents</h3>
        <table>
          <thead>
            <tr><td>Macro</td><td>Unicode character</td><td>Unicode hex value</td></tr>
          </thead>
          <tbody>
            <xsl:for-each select="/texmap/accents/map">
              <tr>
                <td><span class="macro">\<xsl:value-of select="./from/text()"/></span></td>
                <td><span class="utf8"><xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text><xsl:value-of select="./to/text()"/></span></td>
                <td><span class="hex"><xsl:value-of select="./to/@hex"/></span></td>
              </tr>
            </xsl:for-each>              
          </tbody>
        </table>
        <hr/>
        <h3>General Macros</h3>
        <table>
          <thead>
            <tr><td>Macro</td><td>Unicode character</td><td>Unicode hex value</td></tr>
          </thead>
          <tbody>
            <xsl:for-each select="/texmap/wordmacros[@set='base']/map">
              <tr>
                <td><span class="macro">
                  <xsl:if test="./from/@preferred='1'">
                    <xsl:attribute name="class">preferred</xsl:attribute>
                  </xsl:if>
                \<xsl:value-of select="./from/text()"/></span></td>
                <td><span class="utf8"><xsl:value-of select="./to/text()"/></span></td>
                <td><span class="hex"><xsl:value-of select="./to/@hex"/></span></td>
              </tr>
            </xsl:for-each>              
          </tbody>
        </table>
        <hr/>
        <h3>Diacritics</h3>
        <table>
          <thead>
            <tr><td>Macro</td><td>Unicode character</td><td>Unicode hex value</td></tr>
          </thead>
          <tbody>
            <xsl:for-each select="/texmap/diacritics[@set='base']/map">
              <tr>
                <td><span class="macro">
                  <xsl:if test="./from/@preferred='1'">
                    <xsl:attribute name="class">preferred</xsl:attribute>
                  </xsl:if>
                \<xsl:value-of select="./from/text()"/></span></td>
                <td><span class="utf8"><xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text><xsl:value-of select="./to/text()"/></span></td>
                <td><span class="hex"><xsl:value-of select="./to/@hex"/></span></td>
              </tr>
            </xsl:for-each>              
          </tbody>
        </table>
        <hr/>
        <h3>Punctuation</h3>
        <table>
          <thead>
            <tr><td>Macro</td><td>Unicode character</td><td>Unicode hex value</td></tr>
          </thead>
          <tbody>
            <xsl:for-each select="/texmap/punctuation/map">
              <tr>
                <td><span class="macro">
                  <xsl:if test="./from/@preferred='1'">
                    <xsl:attribute name="class">preferred</xsl:attribute>
                  </xsl:if>
                \<xsl:value-of select="./from/text()"/></span></td>
                <td><span class="utf8"><xsl:value-of select="./to/text()"/></span></td>
                <td><span class="hex"><xsl:value-of select="./to/@hex"/></span></td>
              </tr>
            </xsl:for-each>              
          </tbody>
        </table>
        <hr/>
        <h3>Symbols</h3>
        <table>
          <thead>
            <tr><td>Macro</td><td>Unicode character</td><td>Unicode hex value</td></tr>
          </thead>
          <tbody>
            <xsl:for-each select="/texmap/symbols/map">
              <tr class="full">
                <td><span class="macro">
                  <xsl:if test="./from/@preferred='1'">
                    <xsl:attribute name="class">preferred</xsl:attribute>
                  </xsl:if>
                \<xsl:value-of select="./from/text()"/></span></td>
                <td><span class="utf8"><xsl:value-of select="./to/text()"/></span></td>
                <td><span class="hex"><xsl:value-of select="./to/@hex"/></span></td>
              </tr>
            </xsl:for-each>              
          </tbody>
        </table>
        <hr/>
        <h3>Negated Symbols</h3>
        <table>
          <thead>
            <tr><td>Macro</td><td>Unicode character</td><td>Unicode hex value</td></tr>
          </thead>
          <tbody>
            <xsl:for-each select="/texmap/negatedsymbols/map">
              <tr class="full">
                <td><span class="macro">
                  <xsl:if test="./from/@preferred='1'">
                    <xsl:attribute name="class">preferred</xsl:attribute>
                  </xsl:if>
                \not\<xsl:value-of select="./from/text()"/></span></td>
                <td><span class="utf8"><xsl:value-of select="./to/text()"/></span></td>
                <td><span class="hex"><xsl:value-of select="./to/@hex"/></span></td>
              </tr>
            </xsl:for-each>              
          </tbody>
        </table>
        <hr/>
        <h3>Superscripts</h3>
        <table>
          <thead>
            <tr><td>Macro</td><td>Unicode character</td><td>Unicode hex value</td></tr>
          </thead>
          <tbody>
            <xsl:for-each select="/texmap/superscripts/map">
              <tr class="full">
                <td><span class="macro">
                  <xsl:if test="./from/@preferred='1'">
                    <xsl:attribute name="class">preferred</xsl:attribute>
                  </xsl:if>
                \<xsl:value-of select="./from/text()"/></span></td>
                <td><span style="line-height: 120%" class="utf8"><xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text><xsl:value-of select="./to/text()"/></span></td>
                <td><span class="hex"><xsl:value-of select="./to/@hex"/></span></td>
              </tr>
            </xsl:for-each>              
            <xsl:for-each select="/texmap/cmdsuperscripts/map">
              <tr class="full">
                <td><span class="macro">
                  <xsl:if test="./from/@preferred='1'">
                    <xsl:attribute name="class">preferred</xsl:attribute>
                  </xsl:if>
                \<xsl:value-of select="./from/text()"/></span></td>
                <td><span style="line-height: 120%" class="utf8"><xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text><xsl:value-of select="./to/text()"/></span></td>
                <td><span class="hex"><xsl:value-of select="./to/@hex"/></span></td>
              </tr>
            </xsl:for-each>              
          </tbody>
        </table>
        <hr/>
        <h3>Dingbats</h3>
        <table>
          <thead>
            <tr><td>Macro</td><td>Unicode character</td><td>Unicode hex value</td></tr>
          </thead>
          <tbody>
            <xsl:for-each select="/texmap/dings/map">
              <tr class="full">
                <td><span class="macro">
                  <xsl:if test="./from/@preferred='1'">
                    <xsl:attribute name="class">preferred</xsl:attribute>
                  </xsl:if>
                \ding{<xsl:value-of select="./from/text()"/>}</span></td>
                <td><span class="utf8"><xsl:value-of select="./to/text()"/></span></td>
                <td><span class="hex"><xsl:value-of select="./to/@hex"/></span></td>
              </tr>
            </xsl:for-each>              
          </tbody>
        </table>
        <hr/>
        <h3>Greek symbols</h3>
        <table>
          <thead>
            <tr><td>Macro</td><td>Unicode character</td><td>Unicode hex value</td></tr>
          </thead>
          <tbody>
            <xsl:for-each select="/texmap/greek/map">
              <tr class="full">
                <td><span class="macro">
                  <xsl:if test="./from/@preferred='1'">
                    <xsl:attribute name="class">preferred</xsl:attribute>
                  </xsl:if>
                \<xsl:value-of select="./from/text()"/></span></td>
                <td><span class="utf8"><xsl:value-of select="./to/text()"/></span></td>
                <td><span class="hex"><xsl:value-of select="./to/@hex"/></span></td>
              </tr>
            </xsl:for-each>              
          </tbody>
        </table>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
