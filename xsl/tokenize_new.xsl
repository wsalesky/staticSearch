<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:hcmc="http://hcmc.uvic.ca/ns/staticSearch"
    xmlns="http://www.w3.org/1999/xhtml"
    exclude-result-prefixes="#all"
    xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns:pt="http://hcmc.uvic.ca/ns/porter2"
    version="3.0">
    
    <!--JT TO ADD DOCUMENTATION HERE-->
    
    
    <!--Import the configuration file, which is generated via another XSLT-->
    <xsl:include href="config.xsl"/>
    <!--ANd include the PORTER2STEMMER; we should also include PORTER1, I think
        and let users choose which one they want (tho, I don't see why anyone would
        use PORTER1 and not PORTER2-->
    <xsl:include href="porter2Stemmer.xsl"/>
    <xsl:include href="json_module.xsl"/>
    

    
    <!--Simple regular expression for match document names-->
    <xsl:variable name="docRegex">(.+)(\..?htm.?$)</xsl:variable>
    
    <!--Apostrophes-->
    <xsl:variable name="curlyAposOpen">‘</xsl:variable>
    <xsl:variable name="curlyAposClose">’</xsl:variable>
    <xsl:variable name="straightSingleApos">'</xsl:variable>
    <xsl:variable name="curlyDoubleAposOpen">“</xsl:variable>
    <xsl:variable name="curlyDoubleAposClose">”</xsl:variable>
    <xsl:variable name="straightDoubleApos">"</xsl:variable>
    
    <!--REGULAR EXPRESSIONS-->
    <!--THESE REGULAR EXPRESSIONS ALL MUST CONTAIN
        THE QUOTATION MARKS, SINCE WE JUST NORMALIZE THEM AFTER THE FACT-->
    
     <!--purely digits (or decimals) -->
    <xsl:variable name="numericWithDecimal">[<xsl:value-of select="$straightDoubleApos"/>\d]+([\.,]?\d+)</xsl:variable>
    
    <xsl:variable name="alphanumeric">[\p{L}<xsl:value-of select="$straightDoubleApos"/>]+</xsl:variable>
    
    
    <xsl:variable name="hyphenatedWord">(<xsl:value-of select="$alphanumeric"/>-<xsl:value-of select="$alphanumeric"/>(-<xsl:value-of select="$alphanumeric"/>)*)</xsl:variable>
    
    
    <xsl:variable name="tokenRegex">(<xsl:value-of select="string-join(($numericWithDecimal,$hyphenatedWord,$alphanumeric),'|')"/>)</xsl:variable>
    <!--IMPORTANT: Do this to avoid indentation-->
    <xsl:output indent="no" method="xml"/>
    
    <xsl:variable name="count" select="count($docUris)"/>
    
    <!--Basic template-->
    <xsl:template match="/">
 
        <xsl:message>Found <xsl:value-of select="$count"/> documents to process...</xsl:message>
        <xsl:call-template name="echoParams"/>
        <xsl:call-template name="tokenizeDocs"/>
<!--        <xsl:call-template name="createStopwordsJson"/>
        <xsl:call-template name="createConfigJson"/>-->
    </xsl:template>
    
    <xsl:template name="tokenizeDocs">
        <xsl:for-each select="$docUris">
            
            <!--Get the position-->
            <xsl:variable name="pos" select="position()"/>
            
            <xsl:message>Processing <xsl:value-of select="."/> 
                (<xsl:value-of select="$pos"/>/<xsl:value-of select="$count"/>)</xsl:message>
            
            <xsl:variable name="finalDoc" select="
                (if ($hasExclusions) then hcmc:exclude(document(.)) else document(.))
                => hcmc:clean(.)
                => hcmc:weight()
                => hcmc:contextualize()
                => hcmc:tokenize()
                => hcmc:enumerate()"/>
            
     
            
            <xsl:if test="not($finalDoc//html[@data-staticSearch-exclude='true'])">
                <xsl:apply-templates 
                    select="$finalDoc" 
                    mode="json"/>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>
    


    
    <!--DRIVER FUNCTIONS-->
    
    <xsl:function name="hcmc:exclude">
        <xsl:param name="doc"/>
        <xsl:apply-templates select="$doc" mode="exclude"/>
    </xsl:function>
    
    <xsl:function name="hcmc:clean">
        <xsl:param name="doc"/>
        <xsl:param name="uri"/>
        <xsl:apply-templates select="$doc" mode="clean">
            <xsl:with-param name="uri" select="$uri" tunnel="yes"/>
        </xsl:apply-templates>
    </xsl:function>
    
    <xsl:function name="hcmc:weight">
        <xsl:param name="doc"/>
        <xsl:apply-templates select="$doc" mode="weigh"/>
    </xsl:function>
    
    <xsl:function name="hcmc:contextualize">
        <xsl:param name="doc"/>
        <xsl:apply-templates select="$doc" mode="contextualize"/>
    </xsl:function>
    
    <xsl:function name="hcmc:tokenize">
        <xsl:param name="doc"/>
        <xsl:apply-templates select="$doc" mode="tokenize"/>
    </xsl:function>
    
    <xsl:function name="hcmc:enumerate">
        <xsl:param name="doc"/>
        <xsl:apply-templates select="$doc" mode="enumerate"/>
    </xsl:function>
    
    
    
 <!--*****************************************************
     CLEANED TEMPLATES
      ****************************************************-->
    
    <!--This template matches the root HTML element with some parameters
        calculated from before for adding some identifying attributes-->
    <xsl:template match="html" mode="clean">
        
        <xsl:param name="uri" tunnel="yes"/>
        
        <xsl:message>URI: <xsl:value-of select="$uri"/></xsl:message>
        <!--Now find the relative uri from the root:
            this is the full URI minus the collection dir.
            -->
        
        <xsl:variable name="relativeUri"
            select="substring-after($uri,$collectionDir) 
            => replace('^(/|\\)','')" 
            as="xs:string"/>
        
        <!--This is the IDENTIFIER for the static search, which is just the relative URI with all of the punctuation/
             slashes et cetera that could conceivably be in filenames turned into underscores.
            --> 
        <xsl:variable name="searchIdentifier"
            select="replace($relativeUri,'^(/|\\)','') => 
            replace('\.x?html?$','') => 
            replace('\s+|\\|/|\.','_')" 
            as="xs:string"/>
        <xsl:copy>
            <!--Apply templates to all of the attributes on the HTML element
                EXCEPT the id, which we might just duplicate or we might fill in-->
            <xsl:apply-templates select="@*[not(local-name()='id')]" mode="#current"/>
            
            <!--Now (potentially re-)make the id, either using the declared value
                or an inserted value-->
            <xsl:attribute name="id" select="if (@id) then @id else $searchIdentifier"/>
            
            <!--And create a relativeUri in the attribute, so we know where to point
                things if ids and filenames don't match or if nesting-->
            <xsl:attribute name="data-staticSearch-relativeUri" select="$relativeUri"/>
            
            <!--And process nodes normally-->
            <xsl:apply-templates select="node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    

    
    
    
    <!--Basic template to strip away extraneous tags around things we don't care about-->
    <!--Note that this template is overriden with any XPATHS configured in the config file-->
    <xsl:template match="span | em | b | i | a" mode="clean">
        <xsl:if test="$verbose">
            <xsl:message>TEMPLATE clean: Matching <xsl:value-of select="local-name()"/></xsl:message>
        </xsl:if>

        <xsl:apply-templates select="node()" mode="#current"/>
    </xsl:template>
    
    <!--Treat selfclosing elements as a word separating token with the exception of wbr-->
    <xsl:template match="br | hr | area | base | col | embed | hr | img | input | link[ancestor::body] | meta[ancestor::body] | param | source | track" mode="clean">
        <xsl:text> </xsl:text>
    </xsl:template>
    
    <xsl:template match="wbr" mode="clean"/>
    
    <!--Delete script tags by default, since they're code and won't contain anything useful-->
    <xsl:template match="script" mode="clean"/>
    
    
    
  
    <!--Here is where we normalize the string values-->
    <xsl:template match="text()[matches(.,string-join(($curlyAposOpen,$curlyAposClose,$curlyDoubleAposClose, $curlyDoubleAposOpen),'|'))]" mode="clean">
        <xsl:value-of select="replace(.,string-join(($curlyAposOpen,$curlyAposClose),'|'), $straightSingleApos) => replace(string-join(($curlyDoubleAposOpen,$curlyDoubleAposClose),'|'),$straightDoubleApos)"/>
    </xsl:template>
    
    <xsl:template match="*[@lang or @xml:lang][ancestor::body]" mode="clean">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    

    
    <!--*****************************************************
            CONTEXTUALIZE TEMPLATES
      ****************************************************-->
    
    <xsl:template match="body | div | blockquote | p | li | section | article | nav | h1 | h2 | h3 | h4 | h5 | h6 | td | details | summary" mode="contextualize">
        <xsl:copy>
            <xsl:apply-templates select="@*" mode="#current"/>
            <xsl:attribute name="data-staticSearch-context" select="'true'"/>
            <xsl:apply-templates select="node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <!--*****************************************************
            WEIGH TEMPLATES
      ****************************************************-->
    
    <xsl:template match="*[matches(local-name(),'^h\d$')]" mode="weigh">
        <xsl:copy>
            <xsl:apply-templates select="@*" mode="#current"/>
            <xsl:attribute name="data-staticSearch-weight" select="2"/>
            <xsl:apply-templates select="node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    

    
    <!--*****************************************************
            ENUMERATION TEMPLATES
      ****************************************************-->
    
    <!--An accumulator for the stem position-->
    <xsl:accumulator name="stem-position" initial-value="0">
        <xsl:accumulator-rule match="span[@data-staticSearch-stem]">
            <xsl:value-of select="$value + 1"/>
        </xsl:accumulator-rule>
    </xsl:accumulator>
    
    <!--And add a @data-staticSearch-pos to each stem so we know their order-->
    <xsl:template match="span[@data-staticSearch-stem]" mode="enumerate">
        <xsl:copy>
            <xsl:attribute name="data-staticSearch-pos" select="accumulator-before('stem-position')"/>
            <xsl:apply-templates select="@*|node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    

    <!--*****************************************************
            TOKENIZATION TEMPLATES
      ****************************************************-->
    
    <!--The basic thing: tokenizing the string at the text level-->
    <xsl:template match="text()[ancestor::body][not(matches(.,'^\s+$'))][not(ancestor::*[@data-staticSearch-exclude])]" mode="tokenize">
        <xsl:variable name="currNode" select="."/>
        <xsl:variable name="rootLangDeclared" select="boolean(ancestor::html[@lang or @xml:lang])" as="xs:boolean"/>
        <xsl:variable name="langAncestor" select="ancestor::*[not(self::html)][@*:lang][1]" as="element()?"/>
        
        <!--Now to check to see whether or not this thing is declared
            as a foreign language to the root of the document-->
        <xsl:variable name="isForeign">
            <xsl:choose>
                <!--If there is a declared language at the top and theres a lang ancestor
                    then return the negation of whether or not they are equal
                i.e. if they are equal, then return false (since it is NOT foreign)
                -->
                <xsl:when test="$rootLangDeclared and $langAncestor">
                    <xsl:value-of select="not(boolean(ancestor::html/@*:lang = $langAncestor/@*:lang))"/>
                </xsl:when>
                
                <!--If there is a lang ancestor but no root lang declared,
                    then we must assume that it is foreign-->
                <xsl:when test="$langAncestor and not($rootLangDeclared)">
                    <xsl:value-of select="true()"/>
                </xsl:when>
                
                <!--Otherwise, just make it false-->
                <xsl:otherwise>
                    <xsl:value-of select="false()"/>
                </xsl:otherwise>
            </xsl:choose>            
        </xsl:variable>
        
        <!--Match on word tokens-->
        <!--TODO: THIS NEEDS TO BE FINESSED TO HANDLE CONTRACTIONS, 
            DECIMALS, ET CETERA-->
        <xsl:analyze-string select="." regex="{$tokenRegex}">
            <xsl:matching-substring>
                <xsl:if test="$verbose and $isForeign">
                    <xsl:message>Found foreign word: <xsl:value-of select="."/></xsl:message>
                </xsl:if>
                <xsl:copy-of select="hcmc:startStemmingProcess(., $isForeign)"/>
            </xsl:matching-substring>
            <xsl:non-matching-substring>
                <xsl:value-of select="."/>
            </xsl:non-matching-substring>
        </xsl:analyze-string>
    </xsl:template>
    
  
    <!--*****************************************************
            JSON TEMPLATES
      ****************************************************-->
  
    <xsl:template match="html" mode="json">
        <xsl:call-template name="createTokens"/>
        <xsl:call-template name="createTitles"/>
        <xsl:call-template name="createFilters"/>
    </xsl:template>
    
    
    
    
    <!--*****************************************************
            GLOBAL TEMPLATES
      ****************************************************-->
    
    <xsl:template match="html[@data-staticSearch-exclude='true']" mode="#all">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="@*|node()" mode="#all" priority="-1">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    
    <!--*****************************************************
            STEMMING FUNCTIONS
      ****************************************************-->
    
    <xsl:function name="hcmc:startStemmingProcess" as="item()+">
        <xsl:param name="word"/>
        <xsl:param name="isForeign" as="xs:boolean"/>
        <xsl:if test="$verbose">
            <xsl:message>$word: <xsl:value-of select="$word"/></xsl:message>
        </xsl:if>
        
        <xsl:variable name="wordToStem" select="hcmc:cleanWordForStemming($word)"/>
        
        <xsl:if test="$verbose">
            <xsl:message>$wordToStem: <xsl:value-of select="$wordToStem"/></xsl:message>
        </xsl:if>
        
        <xsl:variable name="lcWord" select="lower-case($wordToStem)"/>
        <xsl:if test="$verbose">
            <xsl:message>$lcWord: <xsl:value-of select="$lcWord"/></xsl:message>
        </xsl:if>
        
        <xsl:variable name="shouldIndex" select="hcmc:shouldIndex($lcWord)"/>
        <xsl:if test="$verbose">
            <xsl:message>$shouldIndex: <xsl:value-of select="$shouldIndex"/></xsl:message>
        </xsl:if>
        
        <xsl:choose>
            <xsl:when test="$shouldIndex">
                <xsl:copy-of select="hcmc:getStem($word, $isForeign)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$word"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    
    <!--This function takes in a WORD (i.e. the source text node) and the WORD TO STEM (the cleaned up word)-->
    <xsl:function name="hcmc:getStem" as="element(span)">
        <xsl:param name="word" as="xs:string"/>
        <xsl:param name="isForeign" as="xs:boolean"/>
        <xsl:if test="$verbose">
            <xsl:message>hcmc:getStem: $word: <xsl:value-of select="$word"/></xsl:message>
        </xsl:if>
        
        <xsl:variable name="cleanedWord" select="hcmc:cleanWordForStemming($word)" as="xs:string"/>
        <xsl:if test="$verbose">
            <xsl:message>hcmc:getStem: $cleanedWord: <xsl:value-of select="$cleanedWord"/></xsl:message>
        </xsl:if>
        
        <xsl:variable name="wordToStem" select="$cleanedWord" as="xs:string"/>
        <xsl:if test="$verbose">
            <xsl:message>hcmc:getStem: $wordToStem: <xsl:value-of select="$wordToStem"/></xsl:message>
        </xsl:if>
        
        <xsl:variable name="lcWord" select="lower-case($wordToStem)" as="xs:string"/>
        <xsl:if test="$verbose">
            <xsl:message>hcmc:getStem: $lcWord: <xsl:value-of select="$lcWord"/></xsl:message>
        </xsl:if>
        
        <xsl:variable name="containsCapital" select="matches($wordToStem,'[A-Z]')" as="xs:boolean"/>
        <xsl:if test="$verbose">
            <xsl:message>hcmc:getStem: $containsCapital: <xsl:value-of select="$containsCapital"/></xsl:message>
        </xsl:if>
        
        <xsl:variable name="containsDigit" select="matches($wordToStem,'\d+')" as="xs:boolean"/>
        <xsl:if test="$verbose">
            <xsl:message>hcmc:getStem: $containsDigit: <xsl:value-of select="$containsDigit"/></xsl:message>
        </xsl:if>
        
   
        <xsl:variable name="inDictionary" select="exists(key('w',$lcWord, $dictionaryFileXml))" as="xs:boolean"/>
        <xsl:if test="$verbose">
            <xsl:message>hcmc:getStem: $inDictionary: <xsl:value-of select="$inDictionary"/></xsl:message>
        </xsl:if>
        
        <xsl:variable name="hyphenated" select="matches($word,'[A-Za-z]-[A-Za-z]')" as="xs:boolean"/>
        <xsl:if test="$verbose">
            <xsl:message>hcmc:getStem: hyphenated: <xsl:value-of select="$hyphenated"/></xsl:message>
        </xsl:if>

        
        <xsl:variable name="stemVal" as="xs:string*">
            <xsl:choose>
                <!--If it has a digit, then it makes no sense to stem it-->
                <xsl:when test="$containsDigit">
                    <xsl:value-of select="$wordToStem"/>
                </xsl:when>
                
                <!--If it's foreign, just proceed-->
                <xsl:when test="$isForeign">
                    <xsl:value-of select="$wordToStem"/>
                </xsl:when>
                
                <!--If it contains a capital, then we fork-->
                <xsl:when test="$containsCapital">

                    <!--Produce the stem of the lowercase version-->
                    <xsl:value-of select="pt:stem($lcWord)"/>
                    
                    <!--And if it's not in the dictionary, then return the cleaned word-->
                    <xsl:if test="not($inDictionary)">
                        <xsl:value-of select="concat(substring($wordToStem,1,1),substring($lcWord,2))"/>
                    </xsl:if>
                    
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="pt:stem($lcWord)"/>
                </xsl:otherwise>
                <!--Don't return it if it's not in the dictionary and it's hyphenated;
                    we'll process each individual token instead-->
                
            </xsl:choose>            
        </xsl:variable>
        
        <xsl:if test="$verbose">
            <xsl:message>hcmc:getStem: $stemVal: <xsl:value-of select="string-join($stemVal,' ')"/></xsl:message>
        </xsl:if>
        
        <!--Now do stuff-->
        <!--Wrap it in a span-->
                <span>
                    
                    <!--Add the stem values into an attribute (space separated) if
                    we actually have any-->
                    <xsl:if test="not(empty($stemVal))">
                        <xsl:attribute name="data-staticSearch-stem" 
                            select="string-join($stemVal,' ')"/>
                        
                        
                        <!--If it's not in the dictionary, and it doesn't contain a digit 
                        (assuming here that we don't want digits cross-referenced against
                        the dictionary), then put another attribute to signal that this word doesn't
                        exist in the dictionary-->
                        <xsl:if test="not($inDictionary) and not($containsDigit) and not($isForeign) and not($hyphenated)">
                            <xsl:attribute name="data-staticSearch-notInDictionary" select="$cleanedWord"/>
                        </xsl:if>
                        <xsl:if test="$isForeign">
                            <xsl:attribute name="data-staticSearch-foreign" select="$isForeign"/>
                        </xsl:if>
                    </xsl:if>
                    
                    <!--Fork again, in case we have a hyphenated construct-->
                    <xsl:choose>
                        
                        <!--When we have a hyphenated word, we want to split it into pieces-->
                        <xsl:when test="$hyphenated">
                            <xsl:if test="$verbose">
                                <xsl:message>hcmc:getStem: Found hyphenated construct: <xsl:value-of select="$word"/></xsl:message>
                            </xsl:if>
                            
                            <!--Split the word on the hyphens-->
                            <xsl:variable name="wordTokens" select="tokenize($word,'-')" as="xs:string+"/>
                            
                            <!--Now iterate through the hyphens-->
                            <xsl:for-each select="$wordTokens">
                                <xsl:variable name="thisToken" select="."/>
                                <xsl:variable name="thisTokenPosition" select="position()"/>
                                
                                <!--Spit out a message if we want it-->
                                <xsl:if test="$verbose">
                                    <xsl:message>hcmc:getStem: Process hyphenated segment: <xsl:value-of select="$thisToken"/> (<xsl:value-of select="$thisTokenPosition"/>/<xsl:value-of select="count($wordTokens)"/>)</xsl:message>
                                </xsl:if>
                                
                                <!--Now run each hyphen through the process again, and add hyphens after each word-->
                                <xsl:copy-of select="hcmc:startStemmingProcess(., $isForeign)"/><xsl:if test="$thisTokenPosition ne count($wordTokens)"><xsl:text>-</xsl:text></xsl:if>
                            </xsl:for-each>
                        </xsl:when>
                       
                        <!--If it's not hyphenated, then just plop the content back in-->
                        <xsl:otherwise>
                            <xsl:value-of select="$word"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </span>
    </xsl:function>
    
    
    
    <xsl:function name="hcmc:shouldIndex" as="xs:boolean">
        <xsl:param name="lcWord" as="xs:string"/>
        <xsl:sequence select="string-length($lcWord) gt 2 and not(key('w', $lcWord, $stopwordsFileXml))"/>
    </xsl:function>
    
    <xsl:function name="hcmc:cleanWordForStemming" as="xs:string">
        <xsl:param name="word" as="xs:string"/>
        <!--First, replace any quotation marks in the middle of the word if there happen
            to be any; then trim off any following periods -->
        <xsl:value-of select="replace($word, $straightDoubleApos, '') => replace('\.$','') => translate('ſ','s')"/>
    </xsl:function>
  

    
</xsl:stylesheet>
