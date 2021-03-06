xquery version "3.1";
(: This file handles the transformation of fool's ship xml files :)

module namespace syn2="http://oc.narragonien-digital.de/syn2";
declare default element namespace "http://www.tei-c.org/ns/1.0";

import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://exist-db.org/apps/narrenapp/config" at "config.xqm";

(: Save data-content in variables :)
declare variable $syn2:data := collection('/db/apps/narrenapp/data/GW');
declare variable $syn2:lem := collection('/db/apps/narrenapp/data/lemma');

declare function syn2:getFoolsShip($side as xs:string, $vers as xs:string, $book as xs:string, $chap as xs:string){
(: gets chapters from fool's ship according to user's choice and passes it to syn2:viewFoolsShip() :)
(: Input: $side (synopsis side), $vers (version), $book (GW), $chap (chapter)
Output: user's chosen chapter :)

(: read documents from data/GW :)
for $document in $syn2:data
let $uri := util:unescape-uri(replace(base-uri($document), '.+/(.+).xml$', '$1'), 'UTF-8')
where concat($uri,$vers) eq $book
return

    (: takes body from document :)
    for $body in $document//body
    return
    
    (: compare form-parameters with XML-file IDs :)
    <div id="{concat($uri,$vers)}">
        {for $chapter in $body//div[@type = 'chapter']
        let $id := string($chapter/@xml:id)
        where concat($uri,$id,$vers) eq $chap
        return                   
        <div id="{concat($uri,$id,$vers)}" class="chapterL">{ syn2:tei2html($chapter,$side) }</div>
        }
   </div>
};

declare function syn2:viewFoolsShip($node as node(), $model as map(*), $side as xs:string) {
(: takes necessary content from data/GW and passes it to syn2:tei2html :)
(: Input: data/GW, user's choice from menu, $side (left or right of synopsis)
Output: chapter which was chosen by the user :)

    (: takes parameters from html-form :)
    let $vers1 := request:get-parameter('vers1', '')
    let $book1 := request:get-parameter('book1', '')
    let $chap1 := request:get-parameter('chap1', '')
    let $vers2 := request:get-parameter('vers2', '')
    let $book2 := request:get-parameter('book2', '')
    let $chap2 := request:get-parameter('chap2', '')
    return 
    
    switch($side)
    case "l" return
        syn2:getFoolsShip($side, $vers1, $book1, $chap1)   
    case "r" return
        syn2:getFoolsShip($side, $vers2, $book2, $chap2)                
    default return "Something went wrong."                           
};

declare function syn2:tei2html($nodes as node()*,$side as xs:string) {
(: transforms elements from syn2:viewFoolsShip() :)

    (: reads parameters from synopsis.html :)
    let $vers1 := request:get-parameter('vers1', '')    
    let $vers2 := request:get-parameter('vers2', '')
    
    for $node in $nodes
    return
        typeswitch($node)
        
            case text() return
                $node
                
            case element (ab) return
                    
                if ($node/@type = "chapterTitle") then
                    <div class="chapterTitle" style="font-weight:bold;font-size:1.5em;margin-bottom:3%">{ syn2:tei2html($node/node(),$side) }</div>
                else if ($node/@type = "mainText") then
                    <div class="mainText">{ syn2:tei2html($node/node(),$side) }</div>
                    
                else if ($node/@type = "motto") then
                    <div class="motto" style="font-size:small;margin-bottom:4%">{ syn2:tei2html($node/node(),$side) }</div>
                
                else if ($node/@type = "signatureMark") then
                    (<div class="signatureMark" style="font-size:small;margin-top:4%;text-align:right">{ syn2:tei2html($node/node(),$side) }</div>,
                    <hr class="pageturn"/>)
                    
                else syn2:tei2html($node/node(),$side)
                
            case element (choice) return
            (: normalized and OCR-version of texts :)        
                switch($side)
                    case "l" return
                        switch($vers1)
                            case "reg" return
                                <div class='nrm'>{ for $child in $node//reg return syn2:tei2html($child,$side) }</div>
                            case "orig" return
                                <div class='ocr'>{ for $child in $node//orig return syn2:tei2html($child,$side) }</div>
                            default return ()
                    case "r" return
                        switch($vers2)
                            case "reg" return
                                <div class='nrm'>{ for $child in $node//reg return syn2:tei2html($child,$side) }</div>
                            case "orig" return
                                <div class='ocr'>{ for $child in $node//orig return syn2:tei2html($child,$side) }</div>
                            default return ()
                    default return "WTF"
                    
            case element (figure) return
                <div class="row">
                    <div class="col-sm-10 col-sm-push-2">
                        <img src="resources/img/{ $node/@facs }" style="height:400px;margin-bottom:4%"/>
                    </div>
                </div>
                
            case element (l) return    
                    <div class="row">
                        <div id="line" class="col-sm-2">{ string($node/@n) }</div>
                        <div id="text" class="col-sm-10">{ syn2:tei2html($node/node(),$side) }</div>
                    </div>
             
             (: handling of lems, see also synopsis3.xql :) 
            case element(ref) return 
                
                let $chapter := $node/ancestor::div/@xml:id
                let $uri := util:unescape-uri(replace(base-uri($node), '.+/(.+).xml$', '$1'), 'UTF-8')
                return     
                <button><a  class="lem" data-key="{ concat($uri,$chapter,replace($node/@target,'.+.xml#(.+)$','$1')) }">{ $node/node() }</a></button>
                
            case element() return
                syn2:tei2html($node/node(),$side)
                
            default return $node/string()       
};
