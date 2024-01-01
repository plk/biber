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
      <xsl:when test="string(number($count))='NaN'"/>
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

  <xsl:template name="transliteration-spec">
    <xsl:param name="spec"/>
    <table>
      <thead>
        <tr>
          <td colspan="3"><b>Entrytype: <xsl:value-of select="$spec/@entrytype"/></b></td>
        </tr>
        <tr>
          <td><b>Target</b></td><td><b>From</b></td><td><b>To</b></td>
        </tr>
      </thead>
      <tbody>
        <xsl:for-each select="$spec/bcf:translit">
          <tr>
            <td><xsl:value-of select="./@target"/></td>
            <td><xsl:value-of select="./@from"/></td>
            <td><xsl:value-of select="./@to"/></td>
          </tr>
        </xsl:for-each>
      </tbody>
    </table>
  </xsl:template>
  
  <xsl:template name="sorting-template">
    <xsl:param name="spec"/>
    <h3>Sorting Scheme: <xsl:value-of select="$spec/@name"/></h3>
    <table>
      <thead>
        <tr>
          <xsl:for-each select="$spec/bcf:sort">
            <xsl:sort select="./@order"/>
            <td>
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
                  <xsl:when test="./@sortupper">
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
                    <xsl:if test="./@pad_side='left'">
                      <span class="sort_padding">
                        <xsl:call-template name='generate-string'>
                          <xsl:with-param name='text' select="./@pad_char"/>
                          <xsl:with-param name='count' select="./@pad_width"/>
                        </xsl:call-template>
                      </span>
                    </xsl:if>
                    <!-- left substring -->
                    <xsl:if test="./@substring_side='left'">
                      <span class="sort_substring">
                        <xsl:call-template name="generate-string">
                          <xsl:with-param name="text">&gt;</xsl:with-param>
                          <xsl:with-param name="count" select="./@substring_width"/>
                        </xsl:call-template>
                      </span>
                    </xsl:if>
                    <xsl:value-of select="./text()"/>
                    <!-- right padding -->
                    <xsl:if test="./@pad_side='right'">
                      <span class="sort_padding">
                        <xsl:call-template name="generate-string">
                          <xsl:with-param name="text" select="./@pad_char"/>
                          <xsl:with-param name="count" select="./@pad_width"/>
                        </xsl:call-template>
                      </span>
                    </xsl:if>
                    <!-- right substring -->
                    <xsl:if test="./@substring_side='right'">
                      <span class="sort_substring">
                        <xsl:call-template name="generate-string">
                          <xsl:with-param name="text">&lt;</xsl:with-param>
                          <xsl:with-param name="count" select="./@substring_width"/>
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
      <li><b>Heading key</b>: <xsl:text disable-output-escaping="yes">&amp;uarr;</xsl:text> = ascending sort, <xsl:text disable-output-escaping="yes">&amp;darr;</xsl:text> = descending sort, <tt>Aa</tt> = sort uppercase before lower, <tt>aA</tt> = sort lowercase before upper, <tt>A</tt> = case-sensitive sorting, <tt>a</tt> = case-insensitive sorting, <span class="sort_final">sort fieldset is final master key if defined</span></li>
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
          .small {
            font-size: 70%;
          }
          .key {
            font-size: 70%;
            padding-top: 2ex;
          }
          .map_meta {
            color: #6699CC;
          }
          .sort_padding {
            color: #6699CC;
          }
          .sort_substring {
            color: #FF9933;
          }
          .sort_final {
            background-color: #FFAAAA;
          }
          .map_final {
            color: #FF0000;
          }
          .map_newentry {
            color: #00BB00;
          }
          .map_origentrytype {
            color: #04FF04;
          }
          .map_origfield {
            color: #6699CC;
          }
          .map_origfieldval {
            color: #FF9933;
          }
          .map_null {
            text-decoration: line-through;
          }
          .map_regexp {
            font-size: 60%;
            font-family: "Courier New",monospace;
          }
          .la_fieldkey {
            font-style: italic;
            color: #AAAAAA;
            }
          .la_final {
            color: #FF0000;
          }
          .la_substring {
            color: #FF9933;
          }
          .la_compound {
            color: #6699CC;
          }
          .la_names {
            color: #04FF04;
          }
          .la_namessep {
            color: #FF0000;
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
        <h2><tt>BibLaTeX</tt> Control File (BCF format version: <xsl:value-of select="/bcf:controlfile/@version"/> biblatex version: <xsl:value-of select="/bcf:controlfile/@bltxversion"/>)</h2>
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
                      <td><xsl:value-of select="./bcf:key/text()"/></td>
                      <td><tt><xsl:for-each select="./bcf:value">
                        <xsl:sort select="./@order"/>
                        <xsl:value-of select="./text()"/>
                        <xsl:if test="not(position()=last())">
                          <xsl:text disable-output-escaping="yes">,&amp;nbsp;</xsl:text>
                        </xsl:if>
                      </xsl:for-each></tt></td>
                    </tr>
                  </xsl:when>
                </xsl:choose>                
              </xsl:for-each>
            </tbody>
          </table>
        </xsl:for-each>
        <!-- OPTION SCOPE -->
        <hr/>
        <h3>Option Scope</h3>
        <xsl:for-each select="/bcf:controlfile/bcf:optionscope">
          <table>
            <thead>
              <tr>
                <td colspan="2"><b><xsl:value-of select="./@type"/></b></td>
              </tr>
              <tr>
                <td>Option</td><td>Datatype</td><td>Output by backend?</td><td>Input as by backend</td>
              </tr>
            </thead>
            <tbody>
              <xsl:for-each select="./bcf:option">
                <xsl:sort select="./text()"/>
                <tr>
                  <td><xsl:value-of select="./text()"/></td>
                  <td><xsl:value-of select="./@datatype"/></td>
                  <td><xsl:if test="./@backendout"><xsl:text disable-output-escaping="yes">&amp;#10003;</xsl:text></xsl:if></td>
                  <td><xsl:value-of select="./@backendin"/></td>
                </tr>
              </xsl:for-each>
              </tbody>
          </table>
        </xsl:for-each>
        <!-- DATAFIELD SETS -->
        <hr/>
        <h3>Datafield Sets</h3>
        <table>
          <thead>
            <tr>
              <td><b>Name</b></td><td><b>Members</b></td>
            </tr>
          </thead>
          <tbody>
            <xsl:for-each select="/bcf:controlfile/bcf:datafieldset">
              <tr>
                <td><xsl:value-of select="./@name"/></td>
                <td>
                  <xsl:for-each select="./bcf:member">
                    <xsl:if test="./@datatype">
                      <b>datatype:</b><xsl:value-of select="./@datatype"/>
                      <xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text>
                    </xsl:if>
                    <xsl:if test="./@fieldtype">
                      <b>fieldtype:</b><xsl:value-of select="./@fieldtype"/>
                      <xsl:if test="not(position()=last())">
                        <xsl:text disable-output-escaping="yes">,&amp;nbsp;</xsl:text>
                      </xsl:if>
                    </xsl:if>
                    <xsl:if test="./@field">
                      <xsl:value-of select="./@field"/>
                      <xsl:if test="not(position()=last())">
                        <xsl:text disable-output-escaping="yes">,&amp;nbsp;</xsl:text>
                      </xsl:if>
                    </xsl:if>
                  </xsl:for-each>
                </td>
              </tr>
            </xsl:for-each>
          </tbody>
        </table>
        <!-- DATASOURCE MAPPINGS -->
        <xsl:if test="/bcf:controlfile/bcf:sourcemap">
          <hr/>
          <h3>Datasource Mappings</h3>
          <xsl:for-each select="/bcf:controlfile/bcf:sourcemap/bcf:maps">
            <h4><xsl:value-of select="./@level"/> Mappings for datatype <xsl:value-of select="./@datatype"/> (default overwrite = 
            <xsl:choose>
              <xsl:when test="./@map_overwrite">1</xsl:when>
              <xsl:otherwise>0</xsl:otherwise>
              </xsl:choose>, section = 
              <xsl:choose>
                <xsl:when test="./@refsection">
                  <xsl:value-of select="./@refsection"/>
                </xsl:when>
              <xsl:otherwise>all</xsl:otherwise>
            </xsl:choose>)</h4>
            <xsl:for-each select="./bcf:map">
              <table>
                <thead>
                  <tr>
                  <td align="left">Mapping (<xsl:choose>
                    <xsl:when test="./@map_overwrite">overwrite = <xsl:value-of select="./@map_overwrite"/></xsl:when>
                    <xsl:otherwise>default overwrite</xsl:otherwise>
                  </xsl:choose>
                  <xsl:if test="./bcf:per_type">
                    , <b>for types</b>: 
                    <xsl:for-each select="./bcf:per_type">
                      <xsl:sort select="./text()"/>
                      <xsl:value-of select="./text()"/>
                      <xsl:if test="not(position()=last())">, </xsl:if>
                    </xsl:for-each>
                  </xsl:if>
                  <xsl:if test="./bcf:per_datasource">
                    , <b>for datasources</b>: 
                    <xsl:for-each select="./bcf:per_datasource">
                      <xsl:sort select="./text()"/>
                      <xsl:value-of select="./text()"/>
                      <xsl:if test="not(position()=last())">, </xsl:if>
                    </xsl:for-each>
                  </xsl:if>
                  <xsl:if test="./@map_foreach">
                    , foreach loop field=<xsl:value-of select="./@map_foreach"/>
                  </xsl:if>)</td>
                  </tr>
                </thead>
                <tbody>
                  <xsl:for-each select="./bcf:map_step">
                    <tr><td><xsl:if test="./@map_final='1'">
                          <xsl:attribute name="class">map_final</xsl:attribute>
                        </xsl:if>
                      <xsl:if test="./@map_type_source">
                        <span>@<xsl:value-of select="./@map_type_source"/></span>
                        <xsl:if test="./@map_type_target">
                          <xsl:text disable-output-escaping="yes">&amp;rarr;</xsl:text>@<xsl:value-of select="./@map_type_target"/>
                        </xsl:if>
                      </xsl:if>
                      <xsl:if test="./@map_entry_new">
                        <span><xsl:attribute name="class">map_newentry</xsl:attribute>NEW <xsl:value-of
                        select="./@map_entry_newtype"/> created with key &quot;<xsl:value-of select="./@map_entry_new"/>&quot;</span>
                      </xsl:if>
                      <xsl:if test="./@map_field_source">
                        <span><xsl:value-of select="./@map_field_source"/></span>
                        <xsl:if test="./@map_field_target">
                          <xsl:text disable-output-escaping="yes">&amp;rarr;</xsl:text><xsl:value-of select="./@map_field_target"/>
                        </xsl:if>
                        <xsl:if test="./@map_match"> <xsl:text disable-output-escaping="yes">&amp;asymp;</xsl:text> <span class="map_regexp"><xsl:value-of select="./@map_match"/></span></xsl:if>
                        <xsl:if test="./@map_matchi"> <xsl:text disable-output-escaping="yes">&amp;asymp;</xsl:text> <span class="map_regexp"><xsl:value-of select="./@map_matchi"/></span></xsl:if>
                        <xsl:if test="./@map_notmatch"> <xsl:text disable-output-escaping="yes">&amp;asymp;</xsl:text> <span class="map_regexp"><xsl:value-of select="./@map_notmatch"/></span></xsl:if>
                        <xsl:if test="./@map_notmatchi"> <xsl:text disable-output-escaping="yes">&amp;asymp;</xsl:text> <span class="map_regexp"><xsl:value-of select="./@map_notmatchi"/></span></xsl:if>
                        <xsl:if test="./@map_matches"> <xsl:text disable-output-escaping="yes">&amp;asymp;</xsl:text> <span class="map_regexp"><xsl:value-of select="./@map_matches"/></span></xsl:if>
                        <xsl:if test="./@map_matchesi"> <xsl:text disable-output-escaping="yes">&amp;asymp;</xsl:text> <span class="map_regexp"><xsl:value-of select="./@map_matchesi"/></span></xsl:if>
                        <xsl:if test="./@map_replace"> <xsl:text disable-output-escaping="yes">&amp;rarr;</xsl:text> <span class="map_regexp"><xsl:value-of select="./@map_replace"/></span></xsl:if>
                      </xsl:if>

                      <xsl:if test="./@map_entrykey_cited">
                        <span>Entry must be CITED via \cite{key}</span>
                      </xsl:if>
                      <xsl:if test="./@map_entrykey_nocited">
                        <span>Entry must be NOCITED via \nocite{key} or \nocite{*}</span>
                      </xsl:if>
                      <xsl:if test="./@map_entrykey_citedornocited">
                        <span>Entry must be CITED or NOCITED via \cite{key} or \nocite{key}</span>
                      </xsl:if>
                      <xsl:if test="./@map_entrykey_allnocited">
                        <span>Entry must be NOCITED via \nocite{}</span>
                      </xsl:if>
                      <xsl:if test="./@map_entrykey_starnocited">
                        <span>Entry must only be NOCITED via \nocite{*}</span>
                      </xsl:if>
                      <xsl:if test="./@map_entry_null">
                        <span><xsl:attribute name="class">map_null</xsl:attribute>entry</span>
                      </xsl:if>
                      <xsl:if test="./@map_field_set">
                        <span><xsl:if test="./@map_null='1'">
                          <xsl:attribute name="class">map_null</xsl:attribute>
                        </xsl:if>
                        <xsl:value-of select="./@map_field_set"/></span>
                        <xsl:if test="./@map_field_value">=&quot;<xsl:value-of select="./@map_field_value"/>&quot;</xsl:if>
                        <xsl:if test="./@map_origentrytype='1'">=<span class="map_origentrytype">TYPE</span></xsl:if>
                        <xsl:if test="./@map_origfield='1'">=<span class="map_origfield">FIELD</span></xsl:if>
                        <xsl:if test="./@map_origfieldval='1'">=<span
                        class="map_origfieldval">FIELDVAL</span></xsl:if></xsl:if>
                        <xsl:if test="./@map_entrytarget">
                          <span><xsl:attribute
                                    name="class">map_newentry</xsl:attribute>
                          applied to target &quot;<xsl:value-of select="./@map_entrytarget"/>&quot;</span>
                        </xsl:if>
                    </td></tr>
                  </xsl:for-each>
                </tbody>
              </table>
              <br/>
            </xsl:for-each>
          </xsl:for-each>
          <div class="key"><u>Key</u>
          <ul>
            <li><b><span class="map_final">condition</span></b>: condition must obtain or mapping terminates</li>
            <li><b>@source<xsl:text disable-output-escaping="yes">&amp;rarr;</xsl:text>@target</b>: Change source entrytype to target entrytype</li>
            <li><b>source<xsl:text disable-output-escaping="yes">&amp;rarr;</xsl:text>target</b>: Change source field to target field</li>
            <li><b><span class="map_null">field</span></b>: Delete field</li>
            <li><b><span class="map_null">entry</span></b>: Delete entry</li>
            <li><b>field=&quot;string&quot;</b>: Set field to &quot;string&quot;</li>
            <li><b><span class="map_origentrytype">TYPE</span></b>: Most recently mentioned source entrytype</li>
            <li><b><span class="map_origfield">FIELD</span></b>: Most recently source field</li>
            <li><b><span class="map_origfieldval">FIELDVAL</span></b>: Most recently source field value</li>
            <li><b>field<xsl:text disable-output-escaping="yes">&amp;asymp;</xsl:text>MATCH</b>: field must match Regular Expression MATCH</li>
            <li><b>field<xsl:text disable-output-escaping="yes">&amp;asymp;</xsl:text>MATCH <xsl:text disable-output-escaping="yes">&amp;rarr;</xsl:text> REPLACE</b>: Perform Regular Expression match/replace on field</li>
          </ul>
          </div>
        </xsl:if>
        <!-- LABELALPHA NAME TEMPLATES -->
        <xsl:if test="/bcf:controlfile/bcf:labelalphanametemplate">
          <hr/>
          <h4>Labelalpha Name Templates</h4>
          <xsl:for-each select="/bcf:controlfile/bcf:labelalphanametemplate">
            <h4>Template for type <xsl:value-of select="./@type"/></h4>
            <table>
              <thead>
                <tr><td>Order</td><td>Pre</td><td>Use option</td><td>Width</td><td>Side</td><td>Compound</td><td>Namepart</td></tr>
              </thead>
              <tbody>
                <xsl:for-each select="./bcf:namepart">
                  <xsl:sort select="./@order"/>
                  <tr>
                    <td><xsl:value-of select="./@order"/></td>
                    <td><xsl:value-of select="./@pre"/></td>
                    <td><xsl:value-of select="./@use"/></td>
                    <td><xsl:value-of select="./@substring_width"/></td>
                    <td><xsl:value-of select="./@substring_side"/></td>
                    <td><xsl:value-of select="./@substring_compound"/></td>
                    <td><xsl:value-of select="./text()"/></td>
                  </tr>
                </xsl:for-each>
              </tbody>
            </table>
            <br/>
          </xsl:for-each>
        </xsl:if>
        <!-- LABELALPHA TEMPLATES -->
        <xsl:if test="/bcf:controlfile/bcf:labelalphatemplate">
          <hr/>
          <h3>Labelalpha Templates</h3>
          <xsl:for-each select="/bcf:controlfile/bcf:labelalphatemplate">
            <h4>Template for type <xsl:value-of select="./@type"/></h4>
            <table>
              <thead>
                <tr>
                  <xsl:for-each select="./bcf:labelelement">
                    <xsl:sort select="./@order"/>
                    <td>Part <xsl:value-of select="./@order"/></td>
                  </xsl:for-each>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <xsl:for-each select="./bcf:labelelement">
                    <xsl:sort select="./@order"/>
                    <td>
                      <ul>
                        <xsl:for-each select="./bcf:labelpart">
                          <li>
                            <span>
                              <xsl:if test="./@final='1'">
                                <xsl:attribute name="class">la_final</xsl:attribute>
                              </xsl:if>
                              <xsl:if test="./@substring_compound='1'">
                                <xsl:attribute name="class">la_compound</xsl:attribute>
                              </xsl:if>
                              <xsl:if test="./@ifnames">
                                namecount=<xsl:value-of select="./@ifnames"/><xsl:text disable-output-escaping="yes">&amp;rarr;</xsl:text>
                              </xsl:if>
                              <!-- left substring -->
                              <xsl:if test="./@substring_side='left'">
                                <span class="la_substring">
                                  <xsl:call-template name="generate-string">
                                    <xsl:with-param name="text">&gt;</xsl:with-param>
                                    <xsl:with-param name="count" select="./@substring_width"/>
                                  </xsl:call-template>
                                </span>
                              </xsl:if>
                              <xsl:value-of select="./text()"/>
                              <xsl:if test="./@namessep">
                                <span><xsl:attribute name="class">la_namessep</xsl:attribute>(<xsl:value-of select="./@namessep"/>)</span>
                              </xsl:if>
                              <xsl:if test="./@names">
                                <span><xsl:attribute name="class">la_names</xsl:attribute>=<xsl:value-of select="./@names"/></span>
                              </xsl:if>
                              <!-- right substring -->
                              <xsl:if test="./@substring_side='right'">
                                <span class="la_substring">
                                  <xsl:call-template name="generate-string">
                                    <xsl:with-param name="text">&lt;</xsl:with-param>
                                    <xsl:with-param name="count" select="./@substring_width"/>
                                  </xsl:call-template>
                                </span>
                              </xsl:if>
                              <xsl:if test="./@substring_width='v'">
                                <span class="la_substring">v<xsl:if test="./@substring_width_max">/<xsl:value-of select="./@substring_width_max"/></xsl:if></span>
                              </xsl:if>
                              <xsl:if test="./@substring_width='vf'">
                                <span class="la_substring">vf<xsl:if test="./@substring_fixed_threshold">/<xsl:value-of select="./@substring_fixed_threshold"/></xsl:if></span>
                              </xsl:if>
                              <xsl:if test="./@substring_width='l'">
                                <span class="la_substring">l</span>
                              </xsl:if>
                              <xsl:if test="./@noalphaothers='1'">
                                <span class="la_final"><xsl:text disable-output-escaping="yes">&amp;otimes;</xsl:text></span>
                              </xsl:if>
                            </span>
                          </li>
                        </xsl:for-each>
                      </ul>
                    </td>
                  </xsl:for-each>
                </tr>
              </tbody>
            </table>
          </xsl:for-each>
          <div class="key"><u>Key</u>
          <ul>
            <li><b>Heading key</b>: Label parts are concatenated together in part order shown</li>
            <li><b>Labelpart key</b>: <span class="la_final">Final label, no more parts are considered</span>. &quot;namecount=n<xsl:text disable-output-escaping="yes">&amp;rarr;</xsl:text><span class="la_fieldkey">field</span>&quot; - conditional name <span class="la_fieldkey">field</span>part, only used if there as many names as specified by the range n. Substring specification: &quot;<span class="la_substring">&gt;&gt;&gt;</span><span class="la_fieldkey">field</span>&quot; = use three chars from left side of field. &quot;<span class="la_fieldkey">field</span><span class="la_substring">&lt;&lt;</span>&quot; = use two chars from right side of field. &quot;<span class="la_fieldkey">field</span><span class="la_substring">v/n</span>&quot; = variable-width substring, max n chars. &quot;<span class="la_fieldkey">field</span><span class="la_substring">vf/n</span>&quot; = variable-width substring fixed to same length as longest string occuring at least n times. &quot;<span class="la_fieldkey">field</span><span class="la_substring">l</span>&quot; = list scope disambiguation where the label as a whole is unique, not necessarily the individual parts. &quot;<span class="la_fieldkey">field</span><span class="la_names">&quot;=range</span>=only use the names in the specified range to form the labelpart. &quot;<span class="la_fieldkey">field</span><span class="la_namessep">(string)</span>&quot;=use string as separator between all names. <span class="la_final"><xsl:text disable-output-escaping="yes">&amp;otimes;</xsl:text></span> = supress alphaothers</li>
          </ul>
          </div>
        </xsl:if>
        <!-- EXTRADATE -->
        <xsl:if test="/bcf:controlfile/bcf:extradatespec">
          <hr/>
          <h3>Extradate specification</h3>
          <table>
            <thead>
              <tr>
                <td>Fields</td>
              </tr>
            </thead>
            <tbody>
              <xsl:for-each select="/bcf:controlfile/bcf:extradatespec/bcf:scope">
                <tr>
                  <td>
                    <xsl:for-each select="./bcf:field">
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
        </xsl:if>
        <!-- INHERITANCE -->
        <xsl:if test="/bcf:controlfile/bcf:inheritance">
          <hr/>
          <h3>Inheritance</h3>
          <h4>Defaults</h4>
          <!-- Defaults -->
          <table>
            <thead>
              <tr>
                <td>Child type <xsl:text disable-output-escaping="yes">&amp;asymp;</xsl:text> Parent type</td>
                <td>Source field <xsl:text disable-output-escaping="yes">&amp;rarr;</xsl:text> Target field</td>
                <td>Suppress</td>
              </tr>
            </thead>
            <tbody>
              <!-- Defaults for all types -->
              <tr>
                <td>* <xsl:text disable-output-escaping="yes"> &amp;asymp; </xsl:text> *</td>
                <xsl:choose>
                  <xsl:when test="/bcf:controlfile/bcf:inheritance/bcf:defaults/@inherit_all='true'">
                    <td>
                    <span>
                      <xsl:if test="/bcf:controlfile/bcf:inheritance/bcf:defaults/@override_target='true'">
                        <xsl:attribute name="class">inherit_override</xsl:attribute>
                      </xsl:if>
                    * </span>
                    <xsl:text disable-output-escaping="yes">&amp;rarr;</xsl:text>
                    <span>
                      <xsl:if test="/bcf:controlfile/bcf:inheritance/bcf:defaults/@override_target='false'">
                        <xsl:attribute name="class">inherit_override</xsl:attribute>
                      </xsl:if>
                    * </span>
                    </td>
                  </xsl:when>
                  <xsl:otherwise>
                    <td>
                      <span>
                        <xsl:if test="/bcf:controlfile/bcf:inheritance/bcf:defaults/@override_target='true'">
                          <xsl:attribute name="class">inherit_override</xsl:attribute>
                        </xsl:if>
                      *</span>
                      <xsl:text disable-output-escaping="yes">&amp;rarr;</xsl:text>
                      <span>
                        <xsl:if test="/bcf:controlfile/bcf:inheritance/bcf:defaults/@override_target='false'">
                          <xsl:attribute name="class">inherit_override</xsl:attribute>
                        </xsl:if>
                        <xsl:text disable-output-escaping="yes">&amp;empty;</xsl:text>
                      </span>
                    </td>
                  </xsl:otherwise>
                </xsl:choose>
                <td><xsl:value-of select="/bcf:controlfile/bcf:inheritance/bcf:defaults/@suppress"/></td>
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
                    <xsl:when test="./@inherit_all='true'">
                      <td>
                        <span>
                          <xsl:if test="./@override_target='true'">
                            <xsl:attribute name="class">inherit_override</xsl:attribute>
                          </xsl:if>
                        *</span>
                        <xsl:text disable-output-escaping="yes"> &amp;asymp; </xsl:text>
                        <span>
                          <xsl:if test="./@override_target='false'">
                            <xsl:attribute name="class">inherit_override</xsl:attribute>
                          </xsl:if>
                        *</span>
                      </td>
                    </xsl:when>
                    <xsl:otherwise>
                      <td>
                        <span>
                          <xsl:if test="./@override_target='true'">
                            <xsl:attribute name="class">inherit_override</xsl:attribute>
                          </xsl:if>
                        *</span>
                        <xsl:text disable-output-escaping="yes">&amp;rarr;</xsl:text>
                        <span>
                          <xsl:if test="./@override_target='false'">
                            <xsl:attribute name="class">inherit_override</xsl:attribute>
                          </xsl:if>
                          <xsl:text disable-output-escaping="yes">&amp;empty;</xsl:text>
                        </span>
                      </td>
                    </xsl:otherwise>
                  </xsl:choose>
                  <td><xsl:value-of select="./@suppress"/></td>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
          <h4>Specifications</h4>          
          <table>
            <thead>
              <tr>
                <td>Child type <xsl:text disable-output-escaping="yes">&amp;asymp;</xsl:text> Parent type</td>
                <td>Source field <xsl:text disable-output-escaping="yes">&amp;rarr;</xsl:text> Target field</td>
                <td>Suppress</td>
              </tr>
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
                            <xsl:when test ="./@skip='true'">
                              <xsl:value-of select="./@source"/> <xsl:text disable-output-escaping="yes"> &amp;rarr; </xsl:text> <xsl:text disable-output-escaping="yes">&amp;empty;</xsl:text>
                            </xsl:when>
                            <!-- A normal field inherit specification -->
                            <xsl:otherwise>
                              <span>
                                <xsl:if test="./@override_target='true'">
                                  <xsl:attribute name="class">inherit_override</xsl:attribute>
                                </xsl:if>
                                <xsl:value-of select="./@source"/>
                              </span>
                              <xsl:text disable-output-escaping="yes"> &amp;rarr; </xsl:text>
                              <span>
                                <xsl:if test="./@override_target='false'">
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
                  <td><xsl:value-of select="./@suppress"/></td>
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
            <xsl:for-each select="/bcf:controlfile/bcf:presort">
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
            <xsl:for-each select="/bcf:controlfile/bcf:sortexclusion">
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
        <h4>Sorting inclusions</h4>
        <table>
          <thead>
            <tr><td>Entrytype</td><td>Fields forcibly included in sorting</td></tr>
          </thead>
          <tbody>
            <xsl:for-each select="/bcf:controlfile/bcf:sortinclusion">
              <tr>
                <td>
                  <xsl:value-of select="./@type"/>
                </td>
                <td>
                  <xsl:for-each select="./bcf:inclusion">
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
        <h4>Uniquename Template</h4>
        <table>
          <thead>
            <tr><td>Order</td><td>Base</td><td>Use option</td><td>Disambiguation level</td><td>Namepart</td></tr>
          </thead>
          <tbody>
            <xsl:for-each select="/bcf:controlfile/bcf:uniquenametemplate/bcf:namepart">
              <xsl:sort select="./@order"/>
              <tr>
                <td><xsl:value-of select="./@order"/></td>
                <td><xsl:value-of select="./@base"/></td>
                <td><xsl:value-of select="./@use"/></td>
                <td><xsl:value-of select="./@disambiguation"/></td>
                <td><xsl:value-of select="./text()"/></td>
              </tr>
            </xsl:for-each>
          </tbody>
        </table>
        <br/>
        <h4>Name hash Template</h4>
        <table>
          <thead>
            <tr><td>Order</td><td>Scope</td><td>Namepart</td></tr>
          </thead>
          <tbody>
            <xsl:for-each select="/bcf:controlfile/bcf:namehashtemplate/bcf:namepart">
              <xsl:sort select="./@order"/>
              <tr>
                <td><xsl:value-of select="./@order"/></td>
                <td><xsl:value-of select="./@hashscope"/></td>
                <td><xsl:value-of select="./text()"/></td>
              </tr>
            </xsl:for-each>
          </tbody>
        </table>
        <br/>
        <h4>Sorting Name Key Template</h4>
        <xsl:for-each select="/bcf:controlfile/bcf:sortingnamekeytemplate">
          <table>
            <thead>
              <tr><td colspan="2"><b><xsl:value-of select="./@name"/></b> (visibility: <xsl:value-of select="./@visibility"/>)</td></tr>
              <tr><td>Order</td><td>Keypart</td></tr>
            </thead>
            <tbody>
              <xsl:for-each select="./bcf:keypart">
                <xsl:sort select="./@order"/>
                <tr>
                  <td><xsl:value-of select="./@order"/></td>
                  <td>
                    <xsl:for-each select="./bcf:part">
                      <xsl:sort select="./@order"/>
                      <xsl:value-of select="./text()"/><xsl:if
                      test="./@use"><span class="small"> (if use<xsl:value-of select="./text()"/>=<xsl:value-of select="./@use"/>)</span></xsl:if><xsl:if test="./@inits"> (Initials only)</xsl:if>
                      <xsl:if test="not(position()=last())"> + </xsl:if>
                    </xsl:for-each>
                  </td>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
          <br/>
        </xsl:for-each>
        <h4>Sorting Schemes</h4>
        <xsl:for-each select="/bcf:controlfile/bcf:sortingtemplate">
          <xsl:call-template name="sorting-template">
	          <xsl:with-param name="spec" select="."/>
	        </xsl:call-template>
        </xsl:for-each>
        <xsl:if test="/bcf:controlfile/bcf:transliteration">
          <h4>Sorting Transliteration</h4>
          <xsl:for-each select="/bcf:controlfile/bcf:transliteration">
            <xsl:call-template name="transliteration-spec">
	            <xsl:with-param name="spec" select="."/>
	          </xsl:call-template>
            <br/>
          </xsl:for-each>
        </xsl:if>
        <xsl:if test="/bcf:controlfile/bcf:datamodel">
          <hr/>
          <h3>Data Model</h3>
          <h4>Constants</h4>
          <table>
            <thead>
              <tr><td>Name</td><td>Type</td><td>Value</td></tr>
            </thead>
            <tbody>
              <xsl:for-each select="/bcf:controlfile/bcf:datamodel/bcf:constants/bcf:constant">
                <tr>
                  <td><xsl:value-of select="./@name"/></td>
                  <td><xsl:value-of select="./@type"/></td>
                  <td><xsl:value-of select="./text()"/></td>
                </tr>
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
                    <xsl:for-each select="/bcf:controlfile/bcf:datamodel/bcf:entryfields[not(bcf:entrytype)]/bcf:field">
                      <xsl:sort select="./text()"/>
                      <xsl:value-of select="./text()"/>
                      <xsl:if test="not(position()=last())">, </xsl:if>
                    </xsl:for-each>
                  </div>
                </td>
              </tr>
              <xsl:for-each select="/bcf:controlfile/bcf:datamodel/bcf:entrytypes/bcf:entrytype">
                <tr>
                  <td><xsl:value-of select="./text()"/></td>
                  <!-- Save a varible pointing to the entrytype node -->
                  <xsl:variable name="entrynode" select="current()"/> 
                  <!-- Fields which are valid for this entrytype --> 
                  <td>
                    <!-- If no fields explicitly listed for entrytype, just global fields -->
                    <xsl:if test="not(/bcf:controlfile/bcf:datamodel/bcf:entryfields/bcf:entrytype[text()=$entrynode/text()])">
                      <div class="global_entrytype_fields">GLOBAL fields</div>
                    </xsl:if>
                    <xsl:for-each select="/bcf:controlfile/bcf:datamodel/bcf:entryfields">
                      <!-- fields valid just for this entrytype -->
                      <xsl:if test="./bcf:entrytype[text()=$entrynode/text()]">
                        <!-- List global fields for all entrytypes first -->
                        <div class="global_entrytype_fields">GLOBAL fields</div>
                        <xsl:for-each select="./bcf:field">
                          <xsl:sort select="./text()"/>
                          <xsl:value-of select="./text()"/>
                          <xsl:if test="not(position()=last())">, </xsl:if>
                        </xsl:for-each>
                      </xsl:if>
                    </xsl:for-each>
                  </td>                  
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
          <h4>Field Types</h4>
          <table>
            <thead>
              <tr><td>Field</td><td>Field Format</td><td>Data type</td></tr>
            </thead>
            <tbody>
              <xsl:for-each select="/bcf:controlfile/bcf:datamodel/bcf:fields/bcf:field">
                <tr>
                  <td>
                    <xsl:value-of select="./text()"/>
                    <xsl:if test="./@nullok='true'"><xsl:text disable-output-escaping="yes">&amp;empty;</xsl:text></xsl:if>
                    <xsl:if test="./@skip_output='true'"><xsl:text disable-output-escaping="yes">&amp;loz;</xsl:text></xsl:if>
                  </td>
                  <td>
                    <xsl:choose>
                      <xsl:when test="./@format"><xsl:value-of select="./@format"/></xsl:when>
                      <xsl:otherwise>standard</xsl:otherwise>
                    </xsl:choose>
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
          <xsl:if test="/bcf:controlfile/bcf:datamodel/bcf:constraints">
            <hr/>
            <h3>Constraints</h3>
            <table>
              <thead>
                <tr><td>Entrytypes</td><td>Constraint</td></tr>
              </thead>
              <tbody>
                <xsl:for-each select="/bcf:controlfile/bcf:datamodel/bcf:constraints">
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
        <!-- Section 0 is special as it can be empty and there can be many of them -->
        <h4>Section 0</h4>
        <table>
          <thead>
            <tr><td>Data sources</td><td>Citekeys</td><td>Citekey counts</td><td>Dynamic sets</td></tr>
          </thead>
          <tbody>
            <tr>
              <td>
                <ul>
                  <xsl:for-each select="/bcf:controlfile/bcf:bibdata[@section='0']">
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
                  <xsl:for-each
                      select="/bcf:controlfile/bcf:section[@number='0']/bcf:citekey[not(@type='set')]">
                    <li><tt><xsl:value-of select="./text()"/></tt></li>
                  </xsl:for-each>
                </ul>
              </td>
              <td>
                <ul>
                  <xsl:for-each
                      select="/bcf:controlfile/bcf:section[@number='0']/bcf:citekeycount">
                    <li><tt><xsl:value-of select="./text()"/> (<xsl:value-of select="./@count"/>)</tt></li>
                  </xsl:for-each>
                </ul>
              </td>
              <td>
                <ul>
                  <xsl:for-each
                      select="/bcf:controlfile/bcf:section[@number='0']/bcf:citekey[@type='set']">
                    <li><tt><xsl:value-of select="./text()"/><xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text>(<xsl:value-of select="./@members"/>)</tt></li>
                  </xsl:for-each>
                </ul>
              </td>
            </tr>
          </tbody>
        </table>
        <xsl:for-each select="/bcf:controlfile/bcf:section[@number != '0']">
          <!-- Save a varible pointing to the section number -->
          <xsl:variable name="secnum" select="./@number"/>
          <h4>Section <xsl:value-of select="$secnum"/></h4>
          <table>
            <thead>
              <tr><td>Data sources</td><td>Citekeys</td><td>Citekey counts</td></tr>
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
                <td>
                  <ul>
                    <xsl:for-each select="./bcf:citekeycount">
                      <li><tt><xsl:value-of select="./text()"/> (<xsl:value-of select="./@count"/>)</tt></li>
                    </xsl:for-each>
                  </ul>
                </td>
              </tr>
            </tbody>
          </table>
        </xsl:for-each>
        <h3>Data Lists</h3>
        <xsl:for-each select="/bcf:controlfile/bcf:datalist">
          <h4><u>Data list &quot;<xsl:value-of select="./@name"/>&quot;</u></h4>
          <table>
            <thead>
              <tr><td>Type</td><td>Sorting Scheme</td><td>Labelprefix</td><td>Uniquename Template Name</td><td>Labelalphaname Template Name</td></tr>
            </thead>
            <tbody>
              <tr>
              <td><xsl:value-of select="./@type"/></td>
              <td><xsl:value-of select="./@sortscheme"/></td>
              <td><xsl:value-of select="./@labelprefix"/></td>
              <td><xsl:value-of select="./@uniquenametemplatename"/></td>
              <td><xsl:value-of select="./@labelalphanametemplatename"/></td>
              </tr>
            </tbody>
          </table>
          <xsl:if test="./bcf:filter">
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
          </xsl:if>
        </xsl:for-each>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
<!--
    Copyright 2012-2024 Philip Kime, all rights reserved.

    This code is free software.  You can redistribute it and/or
    modify it under the terms of the Artistic License 2.0.

    This program is distributed in the hope that it will be useful,
    but without any warranty; without even the implied warranty of
    merchantability or fitness for a particular purpose.
-->
