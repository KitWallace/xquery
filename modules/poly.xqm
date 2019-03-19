module namespace poly = "http://kitwallace.co.uk/lib/poly";
declare namespace kml = "http://www.opengis.net/kml/2.2";
import module namespace math ="http://exist-db.org/xquery/math" at "org.exist.xquery.modules.math.MathModule";

declare variable $poly:m-per-Nm := 1852;

declare function poly:point($lat,$long) {
    element point  {
        attribute latitude {$lat},
        attribute longitude {$long}
    }
};
declare function poly:kml-placemark-to-polygons($placemark) {
  for $polygon at $i in $placemark//kml:Polygon
  let $path := $polygon//kml:coordinates
  return poly:kml-coordinates-to-polygon($path)
};

declare function poly:kml-path-to-polygon($placemark) {  
  let $path := $placemark/kml:LineString//kml:coordinates
  return poly:kml-coordinates-to-polygon($path)
};

declare function poly:kml-coordinates-to-polygon($coordinates) {
  element polygon {
     for $point in  tokenize(normalize-space($coordinates)," ")
     let $p := tokenize($point,",")
 
     return 
        element point {attribute latitude {$p[2]},attribute longitude {$p[1]} }
  }
};

declare function poly:polygon-to-kml-coordinates($polygon) {
    string-join(
         for $point in $polygon/point
         return concat($point/@longitude,",",$point/@latitude)
         ," ")
};

declare function poly:polygon-bounding-box($poly) {
  element box {
         element top-left {
                 element point {
                       attribute latitude {max($poly/point/@latitude) },
                       attribute longitude {min($poly/point/@longitude) }
                  }
         },
         element bottom-right {
                 element point {
                      attribute latitude {min($poly/point/@latitude) },
                      attribute longitude {max($poly/point/@longitude) }
                 }
         }
  }
};

declare function poly:polygon-centroid($polygon) {
   let $points := subsequence($polygon/point,2)  (: dont double count the repeated point :)
   return poly:points-centroid($points)
};

declare function poly:points-centroid($points) {
   let $lat := sum($points/@latitude) div count($points)
   let $long := sum($points/@longitude) div count($points)
   return poly:point($lat,$long) 
};

declare function poly:boxes-bounding-box($boxes){
   element box {
         element top-left {element point {attribute latitude {max($boxes//point/@latitude) },
                           attribute longitude {min($boxes//point/@longitude) }
                           }},
         element bottom-right {element point {attribute latitude {min($boxes//point/@latitude) },
                                attribute longitude {max($boxes//point/@longitude) }
                             } }
        }
};

declare function poly:expand-box ($box,$margin) {
   let $margin-lat := $margin div (60 *1850)
   let $margin-long := $margin-lat * math:cos(math:radians($box/top-left/point/@latitude))
   
   return
     element box {
         element top-left {element point {attribute latitude {$box/top-left/point/@latitude + $margin-lat },
                           attribute longitude {$box/top-left/point/@longitude - $margin-long  }
                           }},
         element bottom-right {element point {attribute latitude {$box/bottom-right/point/@latitude - $margin-lat  },
                                attribute longitude {$box/bottom-right/point/@longitude + $margin-long }
                             } }
        }
};

declare function poly:point-in-box($point,$box) {
   $point/@latitude >= xs:double($box/bottom-right/point/@latitude) and
   $point/@latitude <= xs:double($box/top-left/point/@latitude) and
   $point/@longitude <= xs:double($box/bottom-right/point/@longitude) and
   $point/@longitude >= xs:double($box/top-left/point/@longitude) 
};

declare function poly:box-area($box) {
(: in  m2  :)
   let $longcorr := math:cos(math:radians(($box/bottom-right/point/@latitude + $box/top-left/point/@latitude) div 2))
   let $dlat := ($box/top-left/point/@latitude - $box/bottom-right/point/@latitude) * 60 * 1852 
   let $dlong := ($box/bottom-right/point/@longitude - $box/top-left/point/@longitude)  * 60 * 1852  *  $longcorr
   return round($dlat * $dlong)
};
            
declare function poly:box-to-polygon($box) {
   element polygon {
       $box/top-left/point,
       element point{$box/top-left/point/@latitude, $box/bottom-right/point/@longitude},
       $box/bottom-right/point,
       element point{$box/bottom-right/point/@latitude,$box/top-left/point/@longitude},
       $box/top-left/point
   }
};

declare function poly:polygon-is-closed($polygon) {
    $polygon/point[1]/@latitude = $polygon/point[last()]/@latitude and
    $polygon/point[1]/@longitude = $polygon/point[last()]/@longitude 
};

declare function poly:polygon-to-kml($polygon,$name) {
   <Placemark>
       <name>{($name,$polygon/name,"Polygon")[1]}</name>
       <LineString>
       <coordinates>{poly:polygon-to-kml-coordinates($polygon)}</coordinates>
       </LineString>
   </Placemark>
};

declare function poly:polygons-to-kml($polygons,$name,$color) {
    (: color is coded  eg 7fff0000, where alpha=0x7f, blue=0xff, green=0x00, and red=0x00 :)
   <Placemark>
       <name>{($name,"Polygon")[1]}</name>
       	<Style><LineStyle><color>{$color}</color></LineStyle><PolyStyle><fill>0</fill></PolyStyle></Style>
         <MultiGeometry>
         {for $polygon in $polygons
          return 
             <Polygon><outerBoundaryIs><LinearRing>
                  <coordinates>{poly:polygon-to-kml-coordinates($polygon)}</coordinates>
                  </LinearRing></outerBoundaryIs>
             </Polygon>
         }
       </MultiGeometry>
   </Placemark>
};
declare function poly:point-to-kml($point,$name) {
     <Placemark>
       <name>{($name,"Point")[1]}</name>
       <Point>
           <coordinates>{concat($point/@longitude,",",$point/@latitude)}</coordinates>
       </Point>
     </Placemark>
};

declare function poly:close-polygon($polygon) {
    if (poly:polygon-is-closed($polygon))
    then $polygon
    else element polygon {
            $polygon/point,
            $polygon/point[1]
         }
};

declare function poly:poly-to-js($polygons) {
<script type="text/javascript">&#10;
{concat ("var polygons = [ &#10;",
 string-join(
  for $polygon at $i in $polygons
  return
    concat("[&#10;",
    string-join(
        for $point in $polygon/point
        return concat("{lat: ",$point/@latitude,", lng: ",$point/@longitude,"}")  
         ,",&#10;"
        )
    ,"]&#10;"
    )
  ,",&#10;"
  ),
"];&#10;"
)
}
</script>
};

declare function poly:is-left-of-line($p,$a,$b) {
(: true if $p is left of the line $a to $b :)
    ($b/@longitude - $a/@longitude) * ($p/@latitude - $a/@latitude) -
    ($p/@longitude - $a/@longitude) * ($b/@latitude - $a/@latitude) 
};

declare function poly:point-in-polygon($point,$polygon)  {
(: assume polygon is closed
   compute winding number - if 0 then outside
:)
 sum(
    for $p in $polygon/point
    let $pn := $p/following-sibling::point[1]
    return
       if ($p/@latitude <= xs:double($point/@latitude))
       then if ($pn/@latitude > xs:double($point/@latitude))   (: upward crossing :)
            then if (poly:is-left-of-line($point,$p,$pn) > 0) (: point is left of edge :)
                 then 1
                 else 0
            else 0
            
       else if ($pn/@latitude <= xs:double($point/@latitude)) (: downward crossing :)
            then  if (poly:is-left-of-line($point,$p,$pn) < 0)  (: point is right of edge  :)
                 then -1
                 else 0
            else 0
      ) !=0    
};
declare function poly:point-distance-to-line($p,$a,$b) {
(: no longitude correction here - ? does it matter :)
    let $dx :=  $b/@latitude - $a/@latitude
    let $dy :=  $b/@longitude - $a/@longitude
    let $den := math:sqrt ($dx * $dx + $dy * $dy)
    let $num := math:abs($dy * $p/@latitude - $dx * $p/@longitude + $b/@latitude * $a/@longitude - $b/@longitude * $a/@latitude)
    return $num div $den
};

declare function poly:smooth-points($points,$epsilon) {
   let $n := count($points)
   return 
    if ($n <= 2)
    then $points
    else 
    let $start := $points[1]
    let $end := $points[last()]
    let $furthest :=
        (for $p at $i in subsequence($points,2, count($points)-2)
        let $d := poly:point-distance-to-line($p,$start,$end)
        order by $d descending
        return element index {attribute d {$d}, $i + 1}
        )[1]
    return 
        if ($furthest/@d < $epsilon)
        then ($start,$end)
        else let $k := xs:integer($furthest)
             return 
                let $s1 := poly:smooth-points(subsequence($points,1,$k),$epsilon)
                let $s2 := poly:smooth-points(subsequence($points,$k, $n - $k),$epsilon)
                return  
                   (subsequence($s1,1,count($s1)-1),$s2)
};

declare function poly:point-in-polygon($point,$polygon,$box) {
   if (poly:point-in-box($point,$box))
   then poly:point-in-polygon($point,$polygon)
   else false()
};

declare function poly:search-polygons($point,$polygons) {
   for $poly in $polygons
   where poly:point-in-polygon($polint,$poly)
   return $poly
};


declare function poly:area-polygons($area) {
<script type="text/javascript">&#10;
{concat ("var polygons = [ &#10;",
 string-join(
  for $polygon at $i in $area/polygon
  return
    concat("[&#10;",
    string-join(
        for $point in $polygon/point
        return concat("{lat: ",$point/@latitude,", lng: ",$point/@longitude,"}")  
         ,",&#10;"
        )
    ,"]&#10;"
    )
  ,",&#10;"
  ),
"];&#10;"
)
}
</script>
};


declare function poly:compute-area($polygon) {
(: in sq degrees at latitude so needs  correction for latitude and conversion to hectares  
 from https://www.mathopenref.com/coordpolygonarea2.html
:)
    let $n :=  count( $polygon/point)
    let $lat := $polygon/point[1]/@latitude
    let $latcorr := math:cos($lat * 3.14159 div 180)
    return 
      math:abs(sum(
       for $pi at $i in $polygon/point
       let $j := if ($i = $n) then 1 else $i + 1
       let $pj := $polygon/point[$j]
       let $area := ($pi/@longitude + $pj/@longitude )* ($pi/@latitude - $pj/@latitude)
       return $area) * $latcorr * 60 * 60 * 342.99 div 2
       )
};

declare function poly:kml-circle($lat  as xs:double,$long  as xs:double,$radius  as xs:double,$n  as xs:integer) {
    let $long_scale := math:cos(math:radians($lat))
    let $coordinates  :=
       element coordinates {
        string-join(
        for $i in 0 to $n
        let $a := 360 div $n * $i
        let $long-m := $long + $radius *  math:cos(math:radians($a)) div $long_scale div 60 div $poly:m-per-Nm
        let $lat-m :=  $lat + $radius *  math:sin(math:radians($a)) div 60 div $poly:m-per-Nm
        return string-join(($long-m,$lat-m,0),",")
        ,"  ")
       }
    return
      element LineString { $coordinates}
};
