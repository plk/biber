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
        <title>BibLaTeX control file</title>
        <style type="text/css">
          .sortitem_final {
            color: red;
          }
          .sort_label {
            background-color: gray;
          }
        </style>
      </head>
      <body>
        <h2><tt>BibLaTeX</tt> Control File (format version: <xsl:value-of select="/bcf:controlfile/@version"/>)</h2>
        <!-- OPTIONS -->
        <xsl:for-each select="/bcf:controlfile/bcf:options">
          <div class="options_header">&quot;<xsl:value-of select="./@type"/>&quot; options for <tt><xsl:value-of select="./@component"/></tt></div>
          <table class="options_table">
            <thead>
              <tr><td>Option</td><td>Value</td></tr>
            </thead>
            <tbody>
              <xsl:for-each select="./bcf:option">
                <xsl:choose>
                  <xsl:when test="./@type='singlevalued'">
                    <tr><td><xsl:value-of select="./bcf:key/text()"/></td><td><xsl:value-of select="./bcf:value/text()"/></td></tr>
                  </xsl:when>
                  <xsl:when test="./@type='multivalued'">
                    <tr>
                      <td><xsl:value-of select="./bcf:key/text()"/></td>
                      <td><xsl:for-each select="./bcf:value">
                        <xsl:sort select="./@order"/>
                        <xsl:value-of select="./text()"/><xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text>
                      </xsl:for-each></td>
                    </tr>
                  </xsl:when>
                </xsl:choose>                
              </xsl:for-each>
            </tbody>
          </table>
        </xsl:for-each>
        <!-- SORTING -->
        <xsl:for-each select="/bcf:controlfile/bcf:sorting">
          <div class="sorting_header">&quot;<xsl:value-of select="./@type"/>&quot; sorting options</div>
          <table class="sorting_table">
            <tbody>
              <tr>
                <xsl:for-each select="./bcf:sort">
                  <xsl:sort select="./@order"/>
                  <td valign="top">
                    <xsl:if test="./@pass = 'label'">
                      <xsl:attribute name="class">sort_label</xsl:attribute>
                    </xsl:if>
                    <xsl:for-each select="./bcf:sortitem">
                      <xsl:sort select="./@order"/>
                      <span>
                        <xsl:if test="./@final = '1'">
                          <xsl:attribute name="class">sortitem_final</xsl:attribute>
                        </xsl:if>
                        <xsl:value-of select="./text()"/><br/>
                      </span>
                    </xsl:for-each>
                  </td>
                </xsl:for-each>
              </tr>
            </tbody>
          </table>
        </xsl:for-each>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
