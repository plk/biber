<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dcf="https://sourceforge.net/projects/biblatex-biber"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="xs xsl dcf"
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
        <title>Biber drive control file</title>
        <style type="text/css">
          h2,h3,h4 {
            font-family: Arial,sans-serif;
          }
          .plainlist {
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
        <h2><tt>Biber</tt> Driver Control File (driver: <xsl:value-of select="/dcf:driver-control/@driver"/>)</h2>
        <hr/>
        <h3>Description</h3>
        <div><xsl:value-of select="/dcf:driver-control/dcf:description/dcf:overview/text()"/></div>
        <xsl:if test="/dcf:driver-control/dcf:description/dcf:points">
          <div>
            <ul>
            <xsl:for-each select="/dcf:driver-control/dcf:description/dcf:points/dcf:point">
              <li><xsl:value-of select="./text()"/></li>
            </xsl:for-each>
            </ul>
          </div>
        </xsl:if>
        <hr/>
        <h3>Entry types</h3>
        <table>
          <thead>
            <tr><td>Name</td><td>Alias of</td><td>Field settings</td></tr>
          </thead>
          <tbody>
          <xsl:for-each select="/dcf:driver-control/dcf:entrytypes/dcf:entrytype">
            <xsl:sort select="./@name"/>
            <tr>
              <td><xsl:value-of select="./@name"/></td>
              <td><xsl:value-of select="./dcf:aliasof/text()"/></td>
              <td>
                <xsl:if test="./dcf:alsoset">
                  <ul class="plainlist">
                    <xsl:for-each select="./dcf:alsoset">
                      <li><xsl:value-of select="./@target"/> = <xsl:value-of select="./@value"/></li>
                    </xsl:for-each>
                  </ul>
                </xsl:if>
              </td>
            </tr>
          </xsl:for-each>
          </tbody>
        </table>
        <hr/>
        <h3>Fields</h3>
        <table>
          <thead>
            <tr><td>Name</td><td>Driver Handler</td><td>Alias of</td><td>Alias for entrytype</td></tr>
          </thead>
          <tbody>
          <xsl:for-each select="/dcf:driver-control/dcf:fields/dcf:field">
            <xsl:sort select="./@name"/>
            <tr>
              <xsl:choose>
                  <xsl:when test="./dcf:alias">
                    <td><xsl:value-of select="./@name"/></td>
                    <td><xsl:value-of select="./@handler"/></td>
                    <td>
                      <ul>
                      <xsl:for-each select="./dcf:alias">
                        <li><xsl:value-of select="./@aliasof"/></li>
                      </xsl:for-each>
                      </ul>
                    </td>
                    <td>
                      <ul>
                        <xsl:for-each select="./dcf:alias">
                          <xsl:choose>
                            <xsl:when test="./@aliasfortype">
                              <li><xsl:value-of select="./@aliasfortype"/></li>
                            </xsl:when>
                            <xsl:otherwise>*</xsl:otherwise>
                          </xsl:choose>
                        </xsl:for-each>
                      </ul>
                    </td>
                  </xsl:when>
                  <xsl:otherwise>
                    <td><xsl:value-of select="./@name"/></td>
                    <td><xsl:value-of select="./@handler"/></td>
                    <td><xsl:value-of select="./@aliasof"/></td>
                    <td><xsl:if test="not(./@handler)">*</xsl:if></td>
                  </xsl:otherwise>
              </xsl:choose>
            </tr>
          </xsl:for-each>
          </tbody>
        </table>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
