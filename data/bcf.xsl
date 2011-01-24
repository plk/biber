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

  <xsl:template name="generate-string">
    <xsl:param name="text"/>
    <xsl:param name="count"/>

    <xsl:choose>
      <xsl:when test="string-length($text) = 0 or $count &lt;= 0"/>
      <xsl:otherwise>
	<xsl:value-of select="$text"/>
	<xsl:call-template name="generate-string">
	  <xsl:with-param name="text" select="$text"/>
	  <xsl:with-param name="count" select="$count - 1"/>
	</xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="sorting-spec">
    <xsl:param name="spec"/>
    <table>
      <thead>
        <tr>
          <xsl:for-each select="$spec/bcf:sort">
            <xsl:sort select="./@order"/>
            <td>
              <xsl:if test="./@pass='label'">
                <xsl:attribute name="class">sort_label</xsl:attribute>
              </xsl:if>
              <xsl:if test="./@final='1'">
                <xsl:attribute name="class">sort_final</xsl:attribute>
              </xsl:if>
              <xsl:choose>
                <xsl:when test="./@sort_direction='descending'">
                  <xsl:text disable-output-escaping="yes">&amp;darr;</xsl:text>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:text disable-output-escaping="yes">&amp;uarr;</xsl:text>
                </xsl:otherwise>
              </xsl:choose>
              <tt>
                <!-- sortupper -->
                <xsl:choose>
                  <xsl:when test ="./@sortupper">
                    <!-- Field setting -->
                    <xsl:choose>
                      <xsl:when test="./@sortupper='1'">Aa/</xsl:when>
                      <xsl:otherwise>aA/</xsl:otherwise>
                    </xsl:choose>
                  </xsl:when>
                  <xsl:otherwise>
                    <!-- Global setting -->
                    <xsl:choose>
                      <xsl:when test="/bcf:controlfile/bcf:options[@component='biber']/bcf:option/bcf:key[text()='sortupper']/../bcf:value/text()">Aa/</xsl:when>
                      <xsl:otherwise>aA/</xsl:otherwise>
                    </xsl:choose>
                    
                  </xsl:otherwise>
                </xsl:choose>
                <!-- sortcase -->
                <xsl:choose>
                  <xsl:when test ="./@sortcase">
                    <!-- Field setting -->
                    <xsl:choose>
                      <xsl:when test="./@sortcase='1'">A</xsl:when>
                      <xsl:otherwise>a</xsl:otherwise>
                    </xsl:choose>
                  </xsl:when>
                  <xsl:otherwise>
                    <!-- Global setting -->
                    <xsl:choose>
                      <xsl:when test="/bcf:controlfile/bcf:options[@component='biber']/bcf:option/bcf:key[text()='sortcase']/../bcf:value/text()">A</xsl:when>
                      <xsl:otherwise>a</xsl:otherwise>
                    </xsl:choose>
                    
                  </xsl:otherwise>
                </xsl:choose>
              </tt>
            </td>
          </xsl:for-each>
        </tr>
      </thead>
      <tbody>
        <tr>
          <xsl:for-each select="$spec/bcf:sort">
            <xsl:sort select="./@order"/>
            <td>
              <ul>
                <xsl:for-each select="./bcf:sortitem">
                  <xsl:sort select="./@order"/>
                  <li>
                    <!-- left padding -->
                    <xsl:if test="./@pad_side = 'left'">
                      <span class="sort_padding">
                        <xsl:call-template name='generate-string'>
                          <xsl:with-param name='text'><xsl:value-of select="./@pad_char"/></xsl:with-param>
                          <xsl:with-param name='count' select='./@pad_width'/>
                        </xsl:call-template>
                      </span>
                    </xsl:if>
                    <!-- left substring -->
                    <xsl:if test="./@substring_side = 'left'">
                      <span class="sort_substring">
                        <xsl:call-template name='generate-string'>
                          <xsl:with-param name='text'>&gt;</xsl:with-param>
                          <xsl:with-param name='count' select='./@substring_width'/>
                        </xsl:call-template>
                      </span>
                    </xsl:if>
                    <xsl:value-of select="./text()"/>
                    <!-- right padding -->
                    <xsl:if test="./@pad_side='right'">
                      <span class="sort_padding">
                        <xsl:call-template name='generate-string'>
                          <xsl:with-param name='text'><xsl:value-of select="./@pad_char"/></xsl:with-param>
                          <xsl:with-param name='count' select='./@pad_width'/>
                        </xsl:call-template>
                      </span>
                    </xsl:if>
                    <!-- right substring -->
                    <xsl:if test="./@substring_side='right'">
                      <span class="sort_substring">
                        <xsl:call-template name='generate-string'>
                          <xsl:with-param name='text'>&lt;</xsl:with-param>
                          <xsl:with-param name='count' select='./@substring_width'/>
                        </xsl:call-template>
                      </span>
                    </xsl:if>
                  </li>
                </xsl:for-each>
              </ul>
            </td>
          </xsl:for-each>
        </tr>
      </tbody>
    </table>
    <div class="key"><u>Key</u>
    <ul>
      <li><b>Heading Format</b>: (sort-direction)(case-order)/(case-sensitivity)</li>
      <li><b>Heading key</b>: <xsl:text disable-output-escaping="yes">&amp;uarr;</xsl:text> = ascending sort, <xsl:text disable-output-escaping="yes">&amp;darr;</xsl:text> = descending sort, <tt>Aa</tt> = sort uppercase before lower, <tt>aA</tt> = sort lowercase before upper, <tt>A</tt> = case-sensitive sorting, <tt>a</tt> = case-insensitive sorting, <span class="sort_label">sort fieldset valid only for first (label) pass</span>, <span class="sort_final">sort fieldset is final master key if defined</span></li>
      <li><b>Field key</b>: <span class="sort_padding">Padding specification</span> e.g. <span class="sort_padding">0000</span>field = pad field &quot;field&quot; from left with &quot;0&quot; to width 4. <span class="sort_substring">Substring specification</span> e.g. field<span class="sort_substring">&lt;&lt;&lt;&lt;</span> = take width 4 substring from right side of field &quot;field&quot;</li>        
    </ul>
    </div>
  </xsl:template>

  <xsl:template match="/">
    <html>
      <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
        <title>BibLaTeX control file</title>
        <style type="text/css">
          h2,h3,h4 {
            font-family: Arial,sans-serif;
          }
          .key {
            font-size: 70%;
            padding-top: 2ex;
          }
          .sort_final {
            background-color: #FF9999;
          }
          .sort_label {
            background-color: #D0D0D0;
          }
          .sort_padding {
            color: #6699CC;
          }
          .sort_substring {
            color: #FF9933;
          }
          .field_xor_coerce {
            color: #FF0000;
          }
          .inherit_override {
            color: #FF0000;
          }
          .field_nullok {
            background-color: #99FF99;
          }
          .field_skip {
            background-color: #D0D0D0;
          }
          .global_entrytype_fields {
            color: #666666;
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
        <h2><tt>BibLaTeX</tt> Control File (format version: <xsl:value-of select="/bcf:controlfile/@version"/>)</h2>
        <!-- OPTIONS -->
        <hr/>
        <xsl:for-each select="/bcf:controlfile/bcf:options">
          <h3><xsl:value-of select="./@type"/> options for <tt><xsl:value-of select="./@component"/></tt></h3>
          <table>
            <thead>
              <tr><td>Option</td><td>Value</td></tr>
            </thead>
            <tbody>
              <xsl:for-each select="./bcf:option">
                <xsl:choose>
                  <xsl:when test="./@type='singlevalued'">
                    <tr>
                      <td><xsl:value-of select="./bcf:key/text()"/></td>
                      <td><tt><xsl:value-of select="./bcf:value/text()"/></tt></td>
                    </tr>
                  </xsl:when>
                  <xsl:when test="./@type='multivalued'">
                    <tr>
                      <td><tt><xsl:value-of select="./bcf:key/text()"/></tt></td>
                      <td><xsl:for-each select="./bcf:value">
                        <xsl:sort select="./@order"/>
                        <xsl:value-of select="./text()"/>
                        <xsl:if test="not(position()=last())">
                          <xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text>
                        </xsl:if>
                      </xsl:for-each></td>
                    </tr>
                  </xsl:when>
                </xsl:choose>                
              </xsl:for-each>
            </tbody>
          </table>
        </xsl:for-each>
        <!-- INHERITANCE -->
        <xsl:if test="/bcf:controlfile/bcf:inheritance">
          <hr/>
          <h3>Inheritance</h3>
          <h4>Defaults</h4>
          <!-- Defaults -->
          <table>
            <thead>
              <tr><td>Child type <xsl:text disable-output-escaping="yes">&amp;asymp;</xsl:text> Parent type</td><td>Source field <xsl:text disable-output-escaping="yes">&amp;rarr;</xsl:text> Target field</td></tr>
            </thead>
            <tbody>
              <!-- Defaults for all types -->
              <tr>
                <td>* <xsl:text disable-output-escaping="yes"> &amp;asymp; </xsl:text> *</td>
                <xsl:choose>
                  <xsl:when test="/bcf:controlfile/bcf:inheritance/bcf:defaults/@inherit_all='yes'">
                    <td>
                    <span>
                      <xsl:if test="/bcf:controlfile/bcf:inheritance/bcf:defaults/@override_target='yes'">
                        <xsl:attribute name="class">inherit_override</xsl:attribute>
                      </xsl:if>
                    * </span>
                    <xsl:text disable-output-escaping="yes">&amp;rarr;</xsl:text>
                    <span>
                      <xsl:if test="/bcf:controlfile/bcf:inheritance/bcf:defaults/@override_target='no'">
                        <xsl:attribute name="class">inherit_override</xsl:attribute>
                      </xsl:if>
                    * </span>
                    </td>
                  </xsl:when>
                  <xsl:otherwise>
                    <td>
                      <span>
                        <xsl:if test="/bcf:controlfile/bcf:inheritance/bcf:defaults/@override_target='yes'">
                          <xsl:attribute name="class">inherit_override</xsl:attribute>
                        </xsl:if>
                      *</span>
                      <xsl:text disable-output-escaping="yes">&amp;rarr;</xsl:text>
                      <span>
                        <xsl:if test="/bcf:controlfile/bcf:inheritance/bcf:defaults/@override_target='no'">
                          <xsl:attribute name="class">inherit_override</xsl:attribute>
                        </xsl:if>
                        <xsl:text disable-output-escaping="yes">&amp;empty;</xsl:text>
                      </span>
                    </td>
                  </xsl:otherwise>
                </xsl:choose>
              </tr>
              <!-- Defaults for certain types -->
              <xsl:for-each select="/bcf:controlfile/bcf:inheritance/bcf:defaults/bcf:type_pair">
                <tr>
                  <td>
                    <xsl:choose>
                      <xsl:when test ="./@target='all'">*</xsl:when>
                      <xsl:otherwise><xsl:value-of select="./@target"/></xsl:otherwise>
                    </xsl:choose>
                    <xsl:text disable-output-escaping="yes"> &amp;asymp; </xsl:text>
                    <xsl:choose>
                      <xsl:when test ="./@source='all'">*</xsl:when>
                      <xsl:otherwise><xsl:value-of select="./@source"/></xsl:otherwise>
                    </xsl:choose>
                  </td>
                  <xsl:choose>
                    <xsl:when test="./@inherit_all='yes'">
                      <td>
                        <span>
                          <xsl:if test="./@override_target='yes'">
                            <xsl:attribute name="class">inherit_override</xsl:attribute>
                          </xsl:if>
                        *</span>
                        <xsl:text disable-output-escaping="yes"> &amp;asymp; </xsl:text>
                        <span>
                          <xsl:if test="./@override_target='no'">
                            <xsl:attribute name="class">inherit_override</xsl:attribute>
                          </xsl:if>
                        *</span>
                      </td>
                    </xsl:when>
                    <xsl:otherwise>
                      <td>
                        <span>
                          <xsl:if test="./@override_target='yes'">
                            <xsl:attribute name="class">inherit_override</xsl:attribute>
                          </xsl:if>
                        *</span>
                        <xsl:text disable-output-escaping="yes">&amp;rarr;</xsl:text>
                        <span>
                          <xsl:if test="./@override_target='no'">
                            <xsl:attribute name="class">inherit_override</xsl:attribute>
                          </xsl:if>
                          <xsl:text disable-output-escaping="yes">&amp;empty;</xsl:text>
                        </span>
                      </td>
                    </xsl:otherwise>
                  </xsl:choose>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
          <h4>Specifications</h4>          
          <table>
            <thead>
              <tr><td>Child type <xsl:text disable-output-escaping="yes">&amp;asymp;</xsl:text> Parent type</td><td>Source field <xsl:text disable-output-escaping="yes">&amp;rarr;</xsl:text> Target field</td></tr>
            </thead>
            <tbody>
              <xsl:for-each select="/bcf:controlfile/bcf:inheritance/bcf:inherit">
                <tr>
                  <td>
                    <ul>
                      <xsl:for-each select="./bcf:type_pair">
                        <li>
                          <xsl:choose>
                            <xsl:when test ="./@target='all'">*</xsl:when>
                            <xsl:otherwise><xsl:value-of select="./@target"/></xsl:otherwise>
                          </xsl:choose>
                          <xsl:text disable-output-escaping="yes"> &amp;asymp; </xsl:text>
                          <xsl:choose>
                            <xsl:when test ="./@source='all'">*</xsl:when>
                            <xsl:otherwise><xsl:value-of select="./@source"/></xsl:otherwise>
                          </xsl:choose>
                        </li>
                      </xsl:for-each>
                    </ul>
                  </td>
                  <td>
                    <ul>
                      <xsl:for-each select="./bcf:field">
                        <li>
                          <xsl:choose>
                            <!-- A field skip specification -->
                            <xsl:when test ="./@skip='yes'">
                              <xsl:value-of select="./@source"/> <xsl:text disable-output-escaping="yes"> &amp;rarr; </xsl:text> <xsl:text disable-output-escaping="yes">&amp;empty;</xsl:text>
                            </xsl:when>
                            <!-- A normal field inherit specification -->
                            <xsl:otherwise>
                              <span>
                                <xsl:if test="./@override_target='yes'">
                                  <xsl:attribute name="class">inherit_override</xsl:attribute>
                                </xsl:if>
                                <xsl:value-of select="./@source"/>
                              </span>
                              <xsl:text disable-output-escaping="yes"> &amp;rarr; </xsl:text>
                              <span>
                                <xsl:if test="./@override_target='no'">
                                  <xsl:attribute name="class">inherit_override</xsl:attribute>
                                </xsl:if>
                                <xsl:value-of select="./@target"/>
                              </span>
                            </xsl:otherwise>
                          </xsl:choose>
                        </li>
                      </xsl:for-each>
                    </ul>
                  </td>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
          <div class="key"><u>Key</u>
            <ul>
              <li><tt>*</tt> matches all entrytypes or fields</li>
              <li><tt>X</tt><xsl:text disable-output-escaping="yes"> &amp;asymp; </xsl:text><tt>Y</tt>: <tt>X</tt> inherits from<tt> Y</tt></li>
              <li><tt>X</tt><xsl:text disable-output-escaping="yes"> &amp;rarr; &amp;empty;</xsl:text>: Field <tt>X</tt> is suppressed</li>
              <li><tt>F</tt><xsl:text disable-output-escaping="yes"> &amp;rarr; </xsl:text><tt>F'</tt>: Field <tt>F</tt> in parent becomes field <tt>F'</tt> in child. If both field <tt>F</tt> and field <tt>F'</tt> exist, field in <span class="inherit_override">red</span> overrides the other.</li>
            </ul>
          </div>
        </xsl:if>
        <!-- SORTING -->
        <hr/>
        <h3>Global Default Sorting Options</h3>
        <h4>Presort defaults</h4>
        <table>
          <thead>
            <tr><td>Entrytype</td><td>Presort default</td></tr>
          </thead>
          <tbody>
            <xsl:for-each select="/bcf:controlfile/bcf:sorting/bcf:presort">
              <tr>
                <td>
                  <xsl:choose>
                    <xsl:when test="./@type">
                      <xsl:value-of select="./@type"/>
                    </xsl:when>
                    <xsl:otherwise>
                      ALL
                    </xsl:otherwise>
                  </xsl:choose>
                </td>
                <td><tt><xsl:value-of select="./text()"/></tt></td>
              </tr>
            </xsl:for-each>
          </tbody>
        </table>
        <h4>Sorting exclusions</h4>
        <table>
          <thead>
            <tr><td>Entrytype</td><td>Fields excluded from sorting</td></tr>
          </thead>
          <tbody>
            <xsl:for-each select="/bcf:controlfile/bcf:sorting/bcf:sortexclusion">
              <tr>
                <td>
                  <xsl:value-of select="./@type"/>
                </td>
                <td>
                  <xsl:for-each select="./bcf:exclusion">
                    <xsl:value-of select="./text()"/>
                    <xsl:if test="not(position()=last())">
                      <xsl:text disable-output-escaping="yes">,&amp;nbsp;</xsl:text>
                    </xsl:if>
                  </xsl:for-each>
                </td>
              </tr>
            </xsl:for-each>
          </tbody>
        </table>
        <h4>Sorting Specification</h4>
	<xsl:call-template name="sorting-spec">
	  <xsl:with-param name="spec" select="/bcf:controlfile/bcf:sorting"/>
	</xsl:call-template>
        <xsl:if test="/bcf:controlfile/bcf:structure">
          <hr/>
          <h3>Data Structure</h3>
          <h4>Legal datetypes</h4>
          <table>
            <thead>
              <tr><td>Datetypes</td></tr>
            </thead>
            <tbody>
              <xsl:for-each select="/bcf:controlfile/bcf:structure/bcf:datetypes/bcf:datetype">
              <tr><td><xsl:value-of select="./text()"/></td></tr>
              </xsl:for-each>
            </tbody>
          </table>
          <h4>Legal entrytypes</h4>
          <table>
            <thead>
              <tr><td>Entrytype</td><td>Legal fields for entrytype</td></tr>
            </thead>
            <tbody>
              <tr>
                <td>GLOBAL</td>
                <td>
                  <div class="global_entrytype_fields">
                    <xsl:for-each select="/bcf:controlfile/bcf:structure/bcf:entryfields/bcf:entrytype[text()='ALL']/../bcf:field">
                      <xsl:sort select="./text()"/>
                      <xsl:value-of select="./text()"/>
                      <xsl:if test="not(position()=last())">, </xsl:if>
                    </xsl:for-each>
                  </div>
                </td>
              </tr>
              <xsl:for-each select="/bcf:controlfile/bcf:structure/bcf:entrytypes/bcf:entrytype">
                <tr>
                  <td><xsl:value-of select="./text()"/></td>
                  <!-- Save a varible pointing to the entrytype node -->
                  <xsl:variable name="entrynode" select="current()"/> 
                  <!-- Fields which are valid for this entrytype --> 
                  <td>
                    <!-- If no fields explicitly listed for entrytype, just global fields -->
                    <xsl:if test="not(/bcf:controlfile/bcf:structure/bcf:entryfields/bcf:entrytype[text()=$entrynode/text()])">
                      <div class="global_entrytype_fields">GLOBAL fields</div>
                    </xsl:if>
                    <xsl:for-each select="/bcf:controlfile/bcf:structure/bcf:entryfields">
                      <!-- fields valid just for this entrytype -->
                      <xsl:if test="./bcf:entrytype[text()=$entrynode/text()]">
                        <xsl:choose>
                          <!-- Value "ALL" lists every valid field which is a superset
                               of the global fields -->
                          <xsl:when test="./bcf:field[text()='ALL']">
                            <xsl:for-each select="/bcf:controlfile/bcf:structure/bcf:fields/bcf:field">
                              <xsl:sort select="./text()"/>
                              <xsl:value-of select="./text()"/>
                              <xsl:if test="not(position()=last())">, </xsl:if>
                            </xsl:for-each>
                          </xsl:when>
                          <!-- Normal type-specific fields -->
                          <xsl:otherwise>
                            <!-- List global fields for all entrytypes first -->
                            <div class="global_entrytype_fields">GLOBAL fields</div>
                            <xsl:for-each select="./bcf:field">
                              <xsl:sort select="./text()"/>
                              <xsl:value-of select="./text()"/>
                              <xsl:if test="not(position()=last())">, </xsl:if>
                            </xsl:for-each>
                          </xsl:otherwise>
                        </xsl:choose>
                      </xsl:if>
                    </xsl:for-each>
                  </td>                  
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
          <h4>Legal Fields</h4>
          <table>
            <thead>
              <tr><td>Field</td><td>Data type</td></tr>
            </thead>
            <tbody>
              <xsl:for-each select="/bcf:controlfile/bcf:structure/bcf:fields/bcf:field">
                <tr>
                  <td>
                    <xsl:value-of select="./text()"/>
                    <xsl:if test="./@nullok='true'"><xsl:text disable-output-escaping="yes">&amp;empty;</xsl:text></xsl:if>
                    <xsl:if test="./@skip_output='true'"><xsl:text disable-output-escaping="yes">&amp;loz;</xsl:text></xsl:if>
                  </td>
                  <td>
                    <xsl:value-of select="./@datatype"/><xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text><xsl:value-of select="./@fieldtype"/>
                  </td>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
          <div class="key"><u>Key</u>
            <ul>
              <li><xsl:text disable-output-escaping="yes">&amp;empty;</xsl:text> = field can null in <tt>.bbl</tt>, <xsl:text disable-output-escaping="yes">&amp;loz;</xsl:text> = field is not output to <tt>.bbl</tt></li>
            </ul>
          </div>
          <xsl:if test="/bcf:controlfile/bcf:structure/bcf:constraints">
            <hr/>
            <h3>Constraints</h3>
            <table>
              <thead>
                <tr><td>Entrytypes</td><td>Constraint</td></tr>
              </thead>
              <tbody>
                <xsl:for-each select="/bcf:controlfile/bcf:structure/bcf:constraints">
                  <tr>
                    <td>
                      <ul>
                        <xsl:for-each select="./bcf:entrytype">
                          <li>
                            <xsl:value-of select="./text()"/>
                          </li>
                        </xsl:for-each>
                      </ul>
                    </td>
                    <td>
                      <ul>
                        <xsl:for-each select="./bcf:constraint">
                          <li>
                            <xsl:choose>
                              <xsl:when test="./@type='conditional'">
                                <xsl:choose>
                                  <xsl:when test="./bcf:antecedent/@quant='all'"><xsl:text disable-output-escaping="yes">&amp;forall;</xsl:text></xsl:when>
                                  <xsl:when test="./bcf:antecedent/@quant='one'"><xsl:text disable-output-escaping="yes">&amp;exist;</xsl:text></xsl:when>
                                  <xsl:when test="./bcf:antecedent/@quant='none'"><xsl:text disable-output-escaping="yes">&amp;not;&amp;exist;</xsl:text></xsl:when>
                                </xsl:choose>
                                (
                                <xsl:for-each select="./bcf:antecedent/bcf:field">
                                  <xsl:value-of select="./text()"/>
                                  <xsl:if test="not(position()=last())">,</xsl:if>                          
                                </xsl:for-each>
                                )
                                <xsl:text disable-output-escaping="yes">&amp;rarr; </xsl:text>
                                <xsl:choose>
                                  <xsl:when test="./bcf:consequent/@quant='all'"><xsl:text disable-output-escaping="yes">&amp;forall;</xsl:text></xsl:when>
                                  <xsl:when test="./bcf:consequent/@quant='one'"><xsl:text disable-output-escaping="yes">&amp;exist;</xsl:text></xsl:when>
                                  <xsl:when test="./bcf:consequent/@quant='none'"><xsl:text disable-output-escaping="yes">&amp;not;&amp;exist;</xsl:text></xsl:when>
                                </xsl:choose>
                                (
                                <xsl:for-each select="./bcf:consequent/bcf:field">
                                  <xsl:value-of select="./text()"/>
                                  <xsl:if test="not(position()=last())">,</xsl:if>                          
                                </xsl:for-each>
                                )
                              </xsl:when>
                              <xsl:when test="./@type='data'">
                                <xsl:choose>
                                  <xsl:when test="./@datatype='integer'">
                                    <xsl:value-of select="./@rangemin"/><xsl:text disable-output-escaping="yes">&amp;le;</xsl:text>
                                    (
                                    <xsl:for-each select="./bcf:field">
                                      <xsl:value-of select="./text()"/>
                                      <xsl:if test="not(position()=last())">,</xsl:if>                          
                                    </xsl:for-each>
                                    )
                                    <xsl:text disable-output-escaping="yes">&amp;le;</xsl:text><xsl:value-of select="./@rangemax"/>
                                  </xsl:when>
                                  <xsl:when test="./@datatype='datespec'">
                                    (
                                    <xsl:for-each select="./bcf:field">
                                      <xsl:value-of select="./text()"/>
                                      <xsl:if test="not(position()=last())">,</xsl:if>                          
                                    </xsl:for-each>
                                    )
                                    must be dates
                                  </xsl:when>
                                </xsl:choose>
                              </xsl:when>
                            </xsl:choose>
                            <xsl:choose>
                              <xsl:when test="./@type='mandatory'">
                                <xsl:for-each select="./bcf:fieldxor">
                                  <xsl:text disable-output-escaping="yes">&amp;oplus;</xsl:text>
                                  (
                                  <xsl:for-each select="./bcf:field">
                                    <span>
                                      <xsl:if test="./@coerce='true'">
                                        <xsl:attribute name="class">field_xor_coerce</xsl:attribute>
                                      </xsl:if>
                                      <xsl:value-of select="./text()"/>
                                    </span>
                                    <xsl:if test="not(position()=last())">,</xsl:if>                          
                                  </xsl:for-each>
                                  )
                                </xsl:for-each>
                                <xsl:for-each select="./bcf:fieldor">
                                  <xsl:text disable-output-escaping="yes">&amp;or;</xsl:text>
                                  (
                                  <xsl:for-each select="./bcf:field">
                                    <xsl:value-of select="./text()"/>
                                    <xsl:if test="not(position()=last())">,</xsl:if>                          
                                  </xsl:for-each>
                                  )
                                </xsl:for-each>
                              </xsl:when>
                            </xsl:choose>
                          </li>
                        </xsl:for-each>
                      </ul>
                    </td>
                  </tr>
                </xsl:for-each>
              </tbody>
            </table>
            <div class="key"><u>Key</u>
              <ul>            
               <li><tt>C</tt> <xsl:text disable-output-escaping="yes">&amp;rarr;</xsl:text> <tt>C'</tt>: If condition <tt>C</tt> is met then condition <tt>C'</tt> must also be met</li>
               <li><xsl:text disable-output-escaping="yes">&amp;forall;</xsl:text> ( ... ): True if all fields in list exist</li>
               <li><xsl:text disable-output-escaping="yes">&amp;exist;</xsl:text> ( ... ): True if one field in list exists</li>
               <li><xsl:text disable-output-escaping="yes">&amp;not;&amp;exist;</xsl:text> ( ... ): True if no fields in list exist</li>
               <li><tt>n</tt> <xsl:text disable-output-escaping="yes">&amp;le;</xsl:text> ( ... ) <xsl:text disable-output-escaping="yes">&amp;le;</xsl:text> <tt>m</tt>: True if fields in list are have values in the range <tt>n</tt>-<tt>m</tt></li>
               <li><xsl:text disable-output-escaping="yes">&amp;oplus;</xsl:text> ( ... ): True if at least and at most one of the fields in the list exists (XOR). If more than field in the set exists, all will be ignored except for the one in <span class="field_xor_coerce">red</span></li>
               <li><xsl:text disable-output-escaping="yes">&amp;or;</xsl:text> ( ... ): True if at least one of the fields in the list exists (OR)</li>
              </ul>
            </div>
          </xsl:if>
        </xsl:if>
        <hr/>
        <h3>Reference Sections</h3>
        <xsl:for-each select="/bcf:controlfile/bcf:section">
          <!-- Save a varible pointing to the section number -->
          <xsl:variable name="secnum" select="./@number"/> 
          <h4>Section <xsl:value-of select="$secnum"/></h4>
          <table>
            <thead>
              <tr><td>Data sources</td><td>Citekeys</td></tr>
            </thead>
            <tbody>
              <tr>
                <td>
                  <ul>
                    <xsl:for-each select="/bcf:controlfile/bcf:bibdata[@section=$secnum]">
                      <xsl:for-each select="./bcf:datasource">
                        <li>
                          <xsl:value-of select="./text()"/> (<xsl:value-of select="./@datatype"/><xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text><xsl:value-of select="./@type"/>)
                        </li>
                      </xsl:for-each>
                    </xsl:for-each>
                  </ul>
                </td>
                <td>
                  <ul>
                    <xsl:for-each select="./bcf:citekey">
                      <li><tt><xsl:value-of select="./text()"/></tt></li>
                    </xsl:for-each>
                  </ul>
                </td>
              </tr>
            </tbody>
          </table>
          <xsl:for-each select="./bcf:sectionlist">
            <h5><u>Output list &quot;<xsl:value-of select="./@label"/>&quot;</u></h5>
            <div>
              <h6>Filters</h6>
              <table>
                <thead>
                  <tr><td>Filter type</td><td>Filter value</td></tr>
                </thead>
                <tbody>
                  <xsl:for-each select="./bcf:filter">
                    <tr><td><xsl:value-of select="./@type"/></td><td><xsl:value-of select="./text()"/></td></tr>
                  </xsl:for-each>
                </tbody>
              </table>
            </div>
            <div>
              <h6>Sorting Specification</h6>
              <xsl:choose>
                <xsl:when test="./bcf:sorting">
                  <xsl:call-template name="sorting-spec">
                    <xsl:with-param name="spec" select="./bcf:sorting"/>
                  </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                  (global default)
                </xsl:otherwise>
              </xsl:choose>
            </div>
          </xsl:for-each>
        </xsl:for-each>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
