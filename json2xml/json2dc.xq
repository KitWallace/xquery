import module namespace jxml = "http://kitwallace.me/jxml" at "/db/lib/jxml.xqm";
declare namespace dc = "http://purl.org/dc/elements/1.1/";

let $url:= "http://www.omdbapi.com/?s=frozen&amp;r=json"
let $xml := jxml:convert-url($url)
let $movies := element movies {
  for $movie in $xml//*[Title]
  return 
    element movie {
        element dc:title {$movie/Title/string()},
        element dc:relation {$movie/Poster/string()} 
    }
}
return $movies
