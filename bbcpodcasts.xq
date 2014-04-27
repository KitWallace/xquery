(:
 : extract metadata from a BBC Podcast series and optional download to filestore 
 :
 : @param series - the bbcshort name for the series in their url eg  
 :    thpop - Popup ideas  (Tim Harford)
 :    totd  - Tweet of the day
 : @param format  - as html (default), xml, or mp3 download
 : @param mp3dir  - root directory to save mp3s - subdirectory with the series name will be created here
 : update 23 April 23 2014
 :   HTML namespace has been dropped
 :   default directory is OS specific - not sure how to check but its editable anyway
 :
 :)

declare namespace h = "http://www.w3.org/1999/xhtml";
declare variable $local:bbcpodcasts := "http://www.bbc.co.uk/podcasts/series/";

import module namespace date="http://kitwallace.me/date" at "/db/lib/date.xqm";

declare function local:series-list($series) {
    let $url := concat($local:bbcpodcasts, $series,"/all")
    let $doc := httpclient:get(xs:anyURI($url),false(),())/httpclient:body
    return
      element podcasts {
        attribute series { $series },
        attribute source {$url},
        for $mp3 in $doc//div[@id = "pc-keepnet-episodes"]//li
        let $title := $mp3//h3/string()
        let $url := $mp3//p[@class = "pc-episode-cta"]/a/@href/string()
        let $date := $mp3//p[@class = "pc-episode-date"]/string()
        let $xsdate := date:date-from-string($date) 
        order by $xsdate descending
        return
            element podcast {
                element url { $url },
                element title { $title },
                element filename { tokenize($url,"/")[last()]},
                element date { $date },
                element xsdate { $xsdate }, 
                element duration {normalize-space($mp3//p[@class = "pc-episode-duration"]/strong)},
                element description { normalize-space($mp3//p[@class = "pc-episode-description"]) }
            }
      }
};

declare function local:list-as-html($podcasts ,$local as xs:boolean) {
<div>
       <ul>
            {
             for $podcast in $podcasts/podcast
             return
             <li>{ $podcast/date/string() }&#160;
                  {if ($local)
                   then <a href="{ $podcast/filename }">{ $podcast/title/string() }</a> 
                   else <a href="{ $podcast/url }">{ $podcast/title/string() }</a> 
                  }
                 <div style="padding-left: 30px">{ $podcast/description/string()}</div>
             </li>
            }
        </ul>
</div>
};

declare function local:store-podcasts($podcasts, $mp3dir) {
    let $login := xmldb:login("/db", "admin", "perdika")
    let $dir := concat($mp3dir, "/", $podcasts/@series)
    let $mkdir := file:mkdir($dir)
    return
       element result {
            attribute series { $podcasts/@series },
               for $podcast in $podcasts/podcast
               let $filename := $podcast/filename/string()
               let $path := concat($dir, "/", $filename)
               let $store :=
                  if (file:exists($path)) then
                    ()
                  else
                    let $binary := httpclient:get(xs:anyURI($podcast/url), false(), ())/httpclient:body
                    return file:serialize-binary($binary, $path)
               return
                  element podcast {
                    concat($filename, " ",
                           if ($store) then
                               "saved"
                           else if (file:exists($path)) then
                               " already saved"
                           else
                               " not saved"
                           )
                },
                file:serialize(local:list-as-html($podcasts,true()), concat($dir,"/index.html"),"method=xhtml media-type=text/html"),
                file:serialize($podcasts,concat($dir,"/meta.xml"),"method=xml media-type=text/xml")
        }
};
let $series :=  request:get-parameter("series", ())
let $format := request:get-parameter("format", "HTML")
let $mp3dir := request:get-parameter("mp3dir", "c:/podcasts")
let $host := tokenize(request:get-header("X-Forwarded-For"),", ")[1]
let $local :=  empty($host)
let $podcasts := if (exists($series))then local:series-list($series) else ()
return
    if ($format = "HTML") then
        let $serialize := util:declare-option("exist:serialize", "format=xhtml media-type=text/html")
        return
      <html>
        <body>
            <h1>Downloading <a target="_blank" href="http://www.bbc.co.uk/podcasts">BBC podcasts</a></h1>
            <form action="?">
                Series <input type="text" name="series" value="{$series}" size="10" title="the code for the series in the url"/>
                Format <select name="format" >
                              <option>HTML</option>
                              <option>XML</option>
                              {if ($local) then <option>MP3</option> else () }
                       </select>
                {if ($local) then <span>Save in <input type="text" name="mp3dir" id="mp3dir" value="{$mp3dir}" /> </span> else () }
                <input type="submit" name="action" value="Submit"/>
            </form>
        <h1>
             <a href="{ $podcasts/@source/string() }">{ $podcasts/@series/string() }</a>
        </h1>
          {local:list-as-html($podcasts, false())}
       </body>
     </html>
    else if ($format = "XML") then
        $podcasts
    else if ($format = "MP3" and $local) then
        local:store-podcasts($podcasts,$mp3dir)
    else
        ()

  
  
