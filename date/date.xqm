(:
    Module: functions for formatting an xs:dateTime value.
:)
module namespace date="http://kitwallace.me/date";

declare variable $date:months :=
	("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct","Nov", "Dec");
	
declare variable $date:otherMonths :=
	("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sept", "Oct","Nov", "Dec");

declare variable $date:fullMonths :=
	("January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
	"November", "December");

declare variable $date:days :=
  ( "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday");

declare variable $date:shortDays :=
  ( "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun");
  
declare function date:time-from-string($t){
 let $t := normalize-space($t)
 return
  if (matches($t,"^\d\d:\d\d$"))
  then $t
  else if (matches($t,"^\d\d\d\d$"))
  then concat(substring($t,1,2),":",substring($t,3,2))
  else if (matches($t,"^\d\d\d$"))
  then concat ("0",substring($t,1,1),":",substring($t,2,2))
  else if (matches($t,"^\d\.\d\d$"))
  then concat ("0",substring($t,1,1),":",substring($t,3,2))
  else if (matches($t,"^\d:\d\d$")) 
  then concat ("0",substring($t,1,1),":",substring($t,3,2))
  else  if (matches($t,"^\d\d\.\d\d$"))
  then concat (substring($t,1,2),":",substring($t,4,2))
  else ()
};

declare function date:date-from-string($d) {
 (: eg 20 Jan 2001  or 20 January 2011 or Jan 20 2010 or 2010-01-20

     21st Jan 2012 etc not parsed  recognised 
       add (th|nd|st)?  and parse  - but could get the pars form the match rather than tokenize
:)
if (matches($d,"\w\w\w,\s\d+\s\w+\s\d+"))  (: Thu, 15 Aug 13 :)
then 
  let $date := substring-after($d,",")
  let $d := tokenize(normalize-space($date)," ")
  let $month := date:zero-pad(index-of($date:months,$d[2]))
  let $day := date:zero-pad($d[1])
  return concat("20",$d[3],"-",$month,"-",$day)
else if (matches ($d,"\d\d\d\d-\d\d-\d\d"))   (: 2010-01-20 :)
then 
   $d
else if (matches ($d,"\d+\s+\w+\s+\d+"))  (: 20 Jan 2001  or 20 January 2011  :)
then 
  let $dp := tokenize($d,"\s+")
  let $day := $dp[1]
  let $m := $dp[2]
  let $month := (index-of($date:months,$m), index-of($date:fullMonths,$m),index-of($date:otherMonths,$m))[1]
  let $year := $dp[3]
  let $year := if (string-length($year) = 2) then if (xs:integer($year) <50) then concat("20",$year) else concat("19",$year) else $year
  let $date := concat($year,"-",date:zero-pad($month),"-",date:zero-pad($day))
  return 
    if ($date castable as xs:date ) then $date else ()
 else
  if (matches ($d,"\w+\s+\d+\s+\d+"))   (: Jan 20 2010  :)
  then 
  let $dp := tokenize($d,"\s+")
  let $day := $dp[2]
  let $m := $dp[1]
  let $month := (index-of($date:months,$m), index-of($date:fullMonths,$m),index-of($date:otherMonths,$m))[1]
  let $year := $dp[3]
  let $year := if (string-length($year) = 2) then if (xs:integer($year) <50) then concat("20",$year) else concat("19",$year) else $year
  let $date := concat($year,"-",date:zero-pad($month),"-",date:zero-pad($day))
  return 
    if ($date castable as xs:date ) then $date else ()
 else ()
};

  
declare function date:normalize-time($t){
 let $t := normalize-space($t)
 return
  if (matches($t,"^\d\d:\d\d$"))
  then $t
  else if (matches($t,"^\d\d\d\d$"))
  then concat(substring($t,1,2),":",substring($t,3,2))
  else if (matches($t,"^\d\d\d$"))
  then concat ("0",substring($t,1,1),":",substring($t,2,2))
  else if (matches($t,"^\d\.\d\d$"))
  then concat ("0",substring($t,1,1),":",substring($t,3,2))
  else if (matches($t,"^\d:\d\d$")) 
  then concat ("0",substring($t,1,1),":",substring($t,3,2))
  else  if (matches($t,"^\d\d\.\d\d$"))
  then concat (substring($t,1,2),":",substring($t,4,2))
  else ()
};

declare function date:dow-offset($date,$dow) {
   let $downo := index-of($date:days,$dow) - 1
   let $offset := concat("P",$downo,"D")
   return $date + xs:dayTimeDuration($offset)
};

declare function date:daySuffix($n as xs:decimal) as xs:string {
    if ($n =(1,21,31)) then "st"
    else if ($n = (2,22)) then "nd"
    else if ($n = (3,23)) then "rd"
    else "th"
};

declare function date:zero-pad($i) as xs:string {
	if(xs:integer($i) lt 10) then
		concat("0", $i)
	else
		xs:string($i)
};

declare function date:dayOfWeekNo($date) {
(: Monday is 1 :)
    let $day := xs:date($date) - xs:date('2005-01-03')
    return days-from-duration($day) mod 7 + 1
};


declare function date:epoch-seconds-to-dateTime($v) as xs:dateTime{  
    xs:dateTime("1970-01-01T00:00:00-00:00")
  + xs:dayTimeDuration(concat("PT", $v, "S"))
};

(:  conversion from string to date and time :)
declare function date:from-ddmmyyyy-slash($date as xs:string )  as xs:date {
(: 20/01/2007   :)
   let $date := normalize-space($date)
   let $date := tokenize($date,"/")
   return xs:date(concat($date[3],'-',$date[2],'-',$date[1]))
};

declare function date:from-dd-mmm-yy($d) {
 (: eg 20 Jan 2001  or 20 January 2011 or Jan 20 2010 or 2010-01-20 :)
if (matches ($d,"\d\d\d\d-\d\d-\d\d"))
then 
   $d
else if (matches ($d,"\d+\s+\w+\s+\d+"))
then 
  let $dp := tokenize($d,"\s+")
  let $day := $dp[1]
  let $m := $dp[2]
  let $month := (index-of($date:months,$m), index-of($date:fullMonths,$m),index-of($date:otherMonths,$m))[1]
  let $year := $dp[3]
  let $year := if (string-length($year) = 2) then if (xs:integer($year) <50) then concat("20",$year) else concat("19",$year) else $year
  let $date := concat($year,"-",date:zero-pad($month),"-",date:zero-pad($day))
  return 
    if ($date castable as xs:date ) then $date else ()
 else
  if (matches ($d,"\w+\s+\d+\s+\d+"))
  then 
  let $dp := tokenize($d,"\s+")
  let $day := $dp[2]
  let $m := $dp[1]
  let $month := (index-of($date:months,$m), index-of($date:fullMonths,$m),index-of($date:otherMonths,$m))[1]
  let $year := $dp[3]
  let $year := if (string-length($year) = 2) then if (xs:integer($year) <50) then concat("20",$year) else concat("19",$year) else $year
  let $date := concat($year,"-",date:zero-pad($month),"-",date:zero-pad($day))
  return 
    if ($date castable as xs:date ) then $date else ()
 else ()
};

(: no day part yet :)

declare function date:RFC-822-to-date($date as xs:string) as xs:date {
   let $date := 
   if (contains($date,","))
   then normalize-space(substring-after($date,","))
   else $date
  let $d := tokenize($date,"\s")
  let $month := (index-of($date:months,$d[2]),1)[1]
  let $month := date:zero-pad($month)
  let $day :=  xs:integer($d[1])
  let $day := date:zero-pad($day)
  let $year := xs:integer($d[3])
  let $year := if ($year < 20) then 2000 + $year else 1900 + $year
  return concat(string($year),"-",$month,"-",$day)
};


declare function date:RFC-822-to-dateTime-2($date as xs:string) as xs:dateTime  {
  let $d := tokenize($date,"\s")
  let $month := (index-of($date:months,$d[2]),1)[1]
  let $month := date:zero-pad($month)
  let $day :=  xs:integer($d[3])
  let $day := date:zero-pad($day)
  let $year := $d[6]
  let $time := $d[4] 
  return xs:dateTime(concat($year,"-",$month,"-",$day,"T",$time))
};

declare function date:RFC-822-to-dateTime($date as xs:string) as xs:dateTime  {
   let $date := 
   if (contains($date,","))
   then normalize-space(substring-after($date,","))
   else $date
  let $d := tokenize($date,"\s")
  let $month := (index-of($date:months,$d[3]),1)[1]
  let $month := date:zero-pad($month)
  let $day :=  xs:integer($d[2])
  let $day := date:zero-pad($day)
  let $time := $d[5] 
  let $time := if (string-length($time) = 7) then concat("0",$time) else $time
  return xs:dateTime(concat($d[4],"-",$month,"-",$day,"T",$time))
};

declare function date:from-ddmmmyyyytime($date as xs:string) {
(: e.g. 20 Jan 2011 21:45 :)
  let $d := tokenize(normalize-space($date)," ")
  let $month := date:zero-pad(index-of($date:months,$d[2]))
  let $day := date:zero-pad($d[1])
  return concat($d[3],"-",$month,"-",$day,"T",$d[4],":00Z")
};

declare function date:from-dowddmmmyyyytime($date as xs:string) {
(: e.g.  Sun, 20 Jan 2011 21:45:56 +0000 :)
  let $date := substring-after($date,",")
  let $d := tokenize(normalize-space($date)," ")
  let $month := date:zero-pad(index-of($date:months,$d[2]))
  let $day := date:zero-pad($d[1])
  return concat($d[3],"-",$month,"-",$day,"T",$d[4],"Z")
};

declare function date:from-ddMonthYear($date) as xs:date {
(: 20 January 2007 :)
   let $dp := tokenize($date," ")
   let $month := date:zero-pad(index-of($date:months,dp[2]))
   let $ds := string-join(($dp[3],date:zero-pad(number($month)),date:zero-pad(number($dp[1]))),'-')
   return xs:date($ds)
};

declare function date:from-hhmm($time as xs:string)  as xs:time {
   let $time := tokenize($time,":")
   let $min :=  if (string-length($time[1]) <2) then concat("0",$time[1]) else $time[1]
   return  xs:time(concat($min,":",$time[2],":00"))
};

declare function date:from-dmyy($date as xs:string )  as xs:date {
(: 20/1/07   - assume in 2000 century :)
   let $date := normalize-space($date)
   let $date := tokenize($date,"/")
   let $year := concat("20",$date[3])
   let $month := if (string-length($date[2])<2) then concat("0",$date[2]) else $date[2]
   let $day := if (string-length($date[1])<2) then concat("0",$date[1]) else $date[1]
   return xs:date(concat($year,'-',$month,'-',$day))
};

declare function date:from-ddMMMyy($d as xs:string){
(: 20-Mar-95 :)
  let $d := normalize-space($d)
  let $dp := tokenize($d,"-")
  let $mn := index-of($date:months,$dp[2])
  let $mn := if ($mn <10) then concat("0",$mn) else xs:string($mn)
  let $dn := if (string-length($dp[1]) < 2 ) then concat("0",$dp[1]) else $dp[1]
  let $dy := xs:integer($dp[3])
  let $dyc := if ($dy <10) then concat("0",$dy) else xs:string($dy)
  let $dy := if ($dy > 20 ) then concat("19",$dyc) else concat("20",$dyc)
  return 
    string-join(($dy,$mn,$dn),"-")
};


(: operations on dates :)

declare function date:first-of-month($d as xs:date) {
  $d - xdt:dayTimeDuration(concat("P",day-from-date($d) -1,"D"))
};

declare function date:last-of-month($d as xs:date) {
  date:first-of-month($d  + xdt:yearMonthDuration("P1M")) - xdt:dayTimeDuration("P1D")
};



(:   conversions from xs:date xs:time to string :)
(: most of these could be replaced by usage of a general data formater :)

declare function date:to-monddyyyy($date as xs:date) as xs:string {
(:  e.g. Jan 20 2007  :)
    string-join((
             $date:months[month-from-date($date)],
             day-from-date($date),
             year-from-date($date)), " ")
}; 

declare function date:to-dowdayMon($date as xs:date) as xs:string {
(: e.g Wed 20 Jan :)
	string-join((
	               $date:shortDays[date:dayOfWeekNo($date)],
                              day-from-date($date),
		$date:months[month-from-date($date)]
		), " ")
};

declare function date:to-dayMonthYear($date as xs:date) as xs:string {
(: e.g 20st January 2007 :)
	string-join((	
               concat(day-from-date($date),date:daySuffix(day-from-date($date))), 
		$date:fullMonths[month-from-date($date)],
		year-from-date($date)), " ")
};

declare function date:to-ddmmyyyySlash($date as xs:date) as xs:string {
(: e.g. 20/01/2007 :)
           string-join((day-from-date($date),month-from-date($date),year-from-date($date)),'/')
};


declare function date:to-hhmmss($time as xs:time) as xs:string {
(: e.g.  12:45:34  :)
	string-join((
		date:zero-pad(hours-from-dateTime($time)), 
		date:zero-pad(minutes-from-dateTime($time)), 
		date:zero-pad(xs:integer(seconds-from-dateTime($time)))
		),':'	
	)
};

declare function date:to-vcal-datetime($date as xs:date,$time as xs:time) as xs:string {
   let $date := tokenize($date,"-")
   let $time := tokenize($time,":")
   return concat($date[1],$date[2],$date[3],"T",$time[1],$time[2],$time[3],"Z")
};

declare function date:wikidate($date as xs:date) as xs:string {
      concat(year-from-date($date),"_",
             $date:fullMonths[month-from-date($date)],"_",
             day-from-date($date)
             )
};

declare function date:simple-date($date as xs:string) as xs:string {
   let $parts := tokenize($date,"-")
   let $month := if ($parts[2]) then xs:integer($parts[2]) else ()
   let $month := if ($month) then $date:months[$month] else ()
   return concat ($month," ",$parts[1])
};
