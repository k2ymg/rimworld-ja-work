[cmdletBinding()]
param(

[validateSet('all', 'def', 'back', 'key', 'strings')]
[string]$target = 'all',

[validateSet('a','b', 'c')]
[string]$trans = 'a',

[switch]$readable,
[switch]$testMode,
[switch]$clean
)

try{

enum TransMode {
	A
	B
	C
}

class myunko : exception {
	myunko([string]$str) : base($str)
	{
	}
}

class ctx {
	[string] $m_name
	[bool] $m_li_mode
	$m_element

	ctx()
	{
		$this.m_name = $null
		$this.m_li_mode = $false
	}
	ctx([string]$name)
	{
		$this.m_name = $name
		$this.m_li_mode = $false
	}
}

[TransMode]$trans_mode = [TransMode]$trans
[bool]$error_stop = $false
$words = $null


function replace_keep_left([string]$str, [int]$p0, [int]$p1, [int]$p2)
{
	$w = new-object system.text.stringBuilder($str)
	[void]$w.remove($p2, $p1 - $p2 + 2)
	[void]$w.remove($p0, 2)
	$w.toString()
}

function replace_keep_right([string]$str, [int]$p0, [int]$p1, [int]$p2)
{
	$w = new-object system.text.stringBuilder($str)
	[void]$w.remove($p1, 2)
	[void]$w.remove($p0, $p2 - $p0 + 2)
	$w.toString()
}

function replace_keep([string]$str, [int]$p0, [int]$p1)
{
	[int]$p2 = $str.indexOf('/', $p0 + 2, $p1 - $p0 - 2)
	if($p2 -ge 0){
		$w = new-object text.stringBuilder($str)
		[void]$w.remove($p1, 2)
		[void]$w.remove($p0, $p2 - $p0 + 1)
		$w.toString()
	}else{
		$w = new-object text.stringBuilder($str)
		[void]$w.remove($p1, 2)
		[void]$w.remove($p0, 2)
		$w.toString()
	}
}

function replace_replace([string]$str, [int]$p0, [int]$p1)
{
	$key = $str.subString($p0 + 2, $p1 - $p0 - 2)
	$r = $words[$key]
	if(!$r){
		throw [myunko]"Error: Key not found:$($key)"
	}
	$r.count++

	$w = new-object system.text.stringBuilder($str)
	[void]$w.remove($p0, $p1 - $p0 + 2)
	[void]$w.insert($p0, $r.value)
	$w.toString()
}

function replace_remove([string]$str, [int]$p0, [int]$p1)
{
	$w = new-object system.text.stringBuilder($str)
	[void]$w.remove($p0, $p1 - $p0 + 2)
	$w.toString()
}

function replace_keep_simple([string]$str, [int]$p0, [int]$p1)
{
	$w = new-object text.stringBuilder($str)
	[void]$w.remove($p1, 2)
	[void]$w.remove($p0, 2)
	$w.toString()
}

$replacer00 = $null # _<>_
$replacer01 = $null # <<??>>
$replacer10 = $null # _[]_
$replacer11 = $null # [[??]]
$replacer20 = $null # _??_
$replacer_replace = get-item function:replace_replace
switch($trans_mode){
A {
	$replacer00 = get-item function:replace_replace
	$replacer01 = get-item function:replace_keep_right
	$replacer10 = get-item function:replace_replace
	$replacer11 = get-item function:replace_keep_right
	$replacer20 = get-item function:replace_remove
}
B {
	$replacer00 = get-item function:replace_replace
	$replacer01 = get-item function:replace_keep_right
	$replacer10 = get-item function:replace_keep
	$replacer11 = get-item function:replace_keep_left
	$replacer20 = get-item function:replace_keep_simple
}
C {
	$replacer00 = get-item function:replace_keep
	$replacer01 = get-item function:replace_keep_left
	$replacer10 = get-item function:replace_keep
	$replacer11 = get-item function:replace_keep_left
	$replacer20 = get-item function:replace_keep_simple
}
default{
	throw "bad trans mode"
}
}

function replace_sub([string]$str, [int]$p0, [string]$t1, $r)
{
	[int]$p1 = -1

	$p1 = $str.indexOf($t1, $p0 + 2)
	if($p1 -lt 0){
		throw [myunko]"Not match replacement pair:$str"
	}

	& $r $str $p0 $p1
}

function replace_sub_switch([string]$str, [int]$p0, [string]$t1, $r)
{
	[int]$p1 = -1
	[int]$p2 = -1

	$p1 = $str.indexOf($t1, $p0 + 2)
	if($p1 -lt 0){
		throw [myunko]"Not match replacement pair:$str"
	}

	$p2 = $str.indexOf('??', $p0 + 2, $p1 - $p0 - 2)
	if($p2 -lt 0){
		throw [myunko]"Error: no ??"
	}

	& $r $str $p0 $p1 $p2
}

function replace([string]$str)
{
	[int]$p0 = -1
	[int]$p1 = -1
	[int]$count = 0

	if(!$str){
		return $null
	}

	while($true){
		$count++
		if($count -gt 20){
			write-host "Too many replace. Maybe circular reference: $($str)"
			exit
		}

		$v = $null

		$p0 = $str.indexOf('_<')
		if($p0 -ge 0){
			$str = replace_sub $str $p0 '>_' $replacer00
			continue
		}

		$p0 = $str.indexOf('_[')
		if($p0 -ge 0){
			$str = replace_sub $str $p0 ']_' $replacer10
			continue
		}

		$p0 = $str.indexOf('_?')
		if($p0 -ge 0){
			$str = replace_sub $str $p0 '?_' $replacer20
			continue
		}

		$p0 = $str.indexOf('_{')
		if($p0 -ge 0){
			$str = replace_sub $str $p0 '}_' $replacer_replace
			continue
		}

		$p0 = $str.indexOf('<<')
		if($p0 -ge 0){
			$str = replace_sub_switch $str $p0 '>>' $replacer01
			continue
		}

		$p0 = $str.indexOf('[[')
		if($p0 -ge 0){
			$str = replace_sub_switch $str $p0 ']]' $replacer11
			continue
		}

		break
	}

	if(($str.indexOf('>_') -ge 0) -or
		($str.indexOf(']_') -ge 0) -or
		($str.indexOf('?_') -ge 0) -or
		($str.indexOf('}_') -ge 0) -or
		($str.indexOf('::') -ge 0) -or
		($str.indexOf('>>') -ge 0) -or
		($str.indexOf(']]') -ge 0)
	){
		throw [myunko]"Bad pair $($str)"
	}

	$t = $str.indexOf('>')
	if($t -ge 0){
		if(-not (($t -gt 0) -and ($str[$t - 1] -eq '-'))){
			throw [myunko]"Error: included >: $($str)"
		}
	}
	$t = $str.indexOf('<')
	if($t -ge 0){
		throw [myunko]"Error: included <: $($str)"
	}

	#$str.replace('//', "`u{200b}") #faq. zero-width space not work
	$str
}

function make_words
{
	get-childItem -literalPath 'words' -filter *.unko -file | foreach-object {
		$file_name = $_.name
		[int]$count = 0
		get-content -literalPath $_.fullName -encoding utf8 | foreach-object {
			$count++

			if(!$_ -or $_.startsWith(';')){
				return
			}

			$p = $_.indexOf(':')
			if($p -lt 0){
				write-host "Error: No separator: $($file_name)($count): $_"
				$script:error_stop = $true
				return
			}
			$key = $_.subString(0, $p)
			$value = $_.subString($p + 1)

			if(!$value){
				write-host "Error: Value is empty: $($file_name)($count): $_"
				$script:error_stop = $true
			}else{
				if($value.indexOf(':') -ge 0){
					write-host "Error: Contain separator: $($file_name)($count): $_"
					$script:error_stop = $true
				}
			}

			if($words.containsKey($key)){
				write-host "Error: Duplicate: $($file_name)($count): $_"
				$script:error_stop = $true
			}else{
				$o = new-object psobject -property @{value=$value; count=0}
				[void]$words.add($key, $o)
			}
		}
	}
}

function replace_words
{
	foreach($word in $words.getEnumerator()) {
		try{
			$word.value.value = replace($word.value.value)
		}catch [myunko]{
			write-host "Error: $($_): key=$($word.key)"
			if(!$testMode){
				exit
			}
			$script:error_stop = $true
		}
	}
}

function make_name([system.collections.arrayList]$s)
{
	$e = $s.getEnumerator()
	if(!$e.moveNext()){
		return $null# zero
	}
	if(!$e.moveNext()){
		return $null# first, maybe null
	}
	$c = $e.current;
	$w = new-object system.text.stringBuilder($c.m_name)

	while($e.moveNext()){
		$c = $e.current;
		[void]$w.append(".")
		[void]$w.append($c.m_name)
	}
	return $w.toString()
}
$valid_names = get-content -literalPath valid_names.txt
function valid_name([string]$str)
{
	$p0 = $str.lastIndexOf('.')
	if($p0 -lt 0){
		return $true
	}
	$x = $str.subString($p0 + 1)
	if($x -eq '?'){
		return $true
	}
	if($valid_names -ceq $x){
		return $true
	}
	if(!($x -notmatch '^[0-9]')){
		return $true
	}

	return $false
}


#$words = new-object system.collections.hashtable
# ok. case-insensitive
$words = @{}
make_words | out-null
if($error_stop){
	exit
}

replace_words | out-null
if($error_stop){
	exit
}

if(!$testMode){
	$fmt = new-object system.xml.xmlWriterSettings
	if($readable){
		$fmt.indent = $true
		$fmt.IndentChars = ''
	}else{
		$fmt.indent = $false
	}
}

function convert_unko_to_xml([string]$in_file, [string]$out_file, [string]$root_node_name, [bool]$direct_child)
{
	$file_name = resolve-path -relative $in_file

	if(!$testMode){
		$doc = new-object system.xml.xmlDocument
		$doc.appendChild($doc.createXmlDeclaration("1.0", "UTF-8", $null)) | out-null
		$root = $doc.appendChild($doc.createElement($root_node_name))
	}

	$ctx_stack = new-object system.collections.arrayList
	[ctx]$cur_ctx = new-object ctx
	$cur_name = $null

	[int]$line_no = 0
	$tmp_entry = @{}
	[string]$tmp_key = $null
	$tmp_array = $null

	get-content -encoding utf8 -literalPath $in_file | foreach-object {
		$line_no++
		$line = $_.trim()
		if(!$line -or $line.startsWith(';')){
			return
		}

		if($line.startsWith('{')){
			# push

			if($tmp_key){
				write-host $("Error: Not allow block inside $.: {0} ({1})" -F $file_name, $line_no)
				break
			}

			$name = $line.subString(1).trim()
			if(!$name){
				write-host $("Error: Empty block name.: {0} ({1})" -F $file_name, $line_no)
				if($testMode){
					break
				}else{
					exit
				}
			}

			if($name.length -gt 0){
				$last = $name.subString($name.length - 1)
				if($last -notmatch '^[a-z0-9?]'){
					write-host $("Error: Bad name.: {0} ({1})" -F $file_name, $line_no)
					if($testMode){
					}else{
						exit
					}
				}
			}

			if($name.startsWith('$')){
				if($ctx_stack.count -gt 0){
					write-host $("Error: Not allow $ inside block$.: {0} ({1})" -F $file_name, $line_no)
					break
				}

				$tmp_key = $name.subString(1)
				try{
					[void][system.xml.xmlConvert]::VerifyName($tmp_key);
				}catch{
					write-host $("Error: Bad XML name: {0}, {1}" -F $file_name, $line_no)
					write-host Name=[$tmp_key]
					if($testMode){
						return
					}else{
						exit
					}
				}

				$tmp_array = new-object system.collections.arrayList
				$tmp_entry.add($tmp_key, $tmp_array)
				return
			}

			$li_mode = $false
			if($name.startsWith('?')){
				$name = $name.subString(1)
				$li_mode = $true
			}

			[void]$ctx_stack.add($cur_ctx)
			$cur_name = make_name($ctx_stack)
			$cur_ctx = new-object ctx($name)

			if($li_mode){
				$cur_ctx.m_li_mode = $li_mode

				$buf = new-object system.text.stringBuilder($cur_name)
				if($buf.length -gt 0){
					[void]$buf.append(".")
				}
				[void]$buf.append($cur_ctx.m_name)
				$name = $buf.toString()

				if(!$testMode){
					$e = $doc.createElement($name)
					$root.appendChild($e) | out-null
					$cur_ctx.m_element = $e
				}
			}

			if($direct_child){
				if(!$testMode){
					$e = $doc.createElement($name)
					$root.appendChild($e) | out-null
					$cur_ctx.m_element = $e
				}
			}
			return
		}

		if($line.startsWith('}')){
			# pop
			if($tmp_key){
				$tmp_key = $null
				return
			}

			if($ctx_stack.count -le 0){
				write-host $("Error: Not match pair of }}.: {0} ({1})" -F $file_name, $line_no)
				if($testMode){
					break
				}else{
					exit
				}
			}
			$cur_ctx = $ctx_stack[$ctx_stack.count - 1]
			[void]$ctx_stack.removeAt($ctx_stack.count - 1)
			$cur_name = make_name($ctx_stack)
			return
		}

		$p0 = $line.indexOf(':')
		if($p0 -lt 0){
			write-host $("Error: Not found Name-Value separator(:).: {0} ({1})" -F $file_name, $line_no)
			write-host Line=[$line]
			if($testMode){
				return
			}else{
				exit
			}
		}

		$name = $line.subString(0, $p0)
		if($name){
			if($cur_ctx.m_li_mode){
				write-host $("Error: Must be empty in LI mode.: {0} ({1})" -F $file_name, $line_no)
				if($testMode){
					return
				}else{
					exit
				}
			}
		}
		$value = $line.subString($p0 + 1)
		if(!$value){
			write-host $("Error: Empty value :.: {0} ({1})" -F $file_name, $line_no)
			write-host Use _??_ for avoid error.
			if($testMode){
				return
			}else{
				exit
			}
		}

		if($name.startsWith('$')){
			if($tmp_key){
				write-host $("Error: Not allow $ inside $ block.: {0} ({1})" -F $file_name, $line_no)
				if($testMode){
					return
				}else{
					exit
				}
			}

			if(!$value){
				write-host $("Error: No key of $.: {0} ({1})" -F $file_name, $line_no)
				if($testMode){
					return
				}else{
					exit
				}
			}

			$a = $tmp_entry[$value]
			if(!$a){
				write-host $("Error: Not found key or empty of $.: {0} ({1})" -F $file_name, $line_no)
				write-host Key:$value
				if($testMode){
					return
				}else{
					exit
				}
			}
			
			$buf = new-object system.text.stringBuilder($cur_name)
			if($buf.length -gt 0){
				[void]$buf.append(".")
			}
			[void]$buf.append($cur_ctx.m_name)
			$name = $buf.toString()

			foreach($aa in $a){
				$en = $name + "." + $aa.m_name
				if(!$(valid_name $en)){
					write-host $("Error: Bad element name: {0}, {1}" -F $file_name, $line_no)
					write-host $en
					if(!$testMode){
						exit
					}
				}
				if(!$testMode){
					$e = $doc.createElement($en)
					$e.innerText = $aa.m_value
					$root.appendChild($e) | out-null
				}
			}
			
			return
		}

		try{
			$value = replace($value)
		}catch [myunko]{
			write-host $("Error: {0}: {1} ({2})" -F $_, $file_name, $line_no)
			if(!$testMode){
				exit
			}
		}

		if($tmp_key){
			if($name){
				$e = new-object psobject -property @{m_name=$name; m_value=$value}
				[void]$tmp_array.add($e)
			}else{
				write-host $("Error: Empty name: {1} ({2})" -F $_, $file_name, $line_no)
				if(!$testMode){
					exit
				}
			}
			return
		}

		if($true){
			if(!$direct_child){
				$buf = new-object system.text.stringBuilder($cur_name)
				if($buf.length -gt 0){
					[void]$buf.append(".")
				}
				[void]$buf.append($cur_ctx.m_name)

				if($name){
					if($buf.length -gt 0){
						[void]$buf.append(".")
					}
					[void]$buf.append($name)
				}else{
					if(!$cur_ctx.m_li_mode){
						write-host $("Error: No name in LI block: {0}, {1}" -F $file_name, $line_no)
						if(!$testMode){
							exit
						}
					}
				}
				$name = $buf.toString()
			}

			try{
				[void][system.xml.xmlConvert]::VerifyName($name);
			}catch{
				write-host $("Error: Bad element name: {0}, {1}" -F $file_name, $line_no)
				write-host Name=[$name]
				write-host $_
				write-host ""
				if(!$testMode){
					exit
				}
			}

			if(!$(valid_name $name)){
				write-host $("Error: Bad element name: {0}, {1}" -F $file_name, $line_no)
				write-host $name
				if(!$testMode){
						exit
				}
			}

			if(!$testMode){
				if($cur_ctx.m_li_mode){
					$e = $doc.createElement('li')
					$e.innerText = $value
					$cur_ctx.m_element.appendChild($e) | out-null
				}else{
					if($direct_child){
						$e = $doc.createElement($name)
						$e.innerText = $value
						$cur_ctx.m_element.appendChild($e) | out-null
					}else{
						$e = $doc.createElement($name)
						$e.innerText = $value
						$root.appendChild($e) | out-null
					}
				}
			}
		}
		return
	}

	if($tmp_key){
		write-host $("{0}: Unclosed $ block" -F $file_name)
		if(!$testMode){
			exit
		}
	}

	if($ctx_stack.count -gt 0){
		write-host $("{0}: Unclosed block" -F $file_name)
		if(!$testMode){
			exit
		}
	}

	if(!$testMode){
		try{
			$w = [system.xml.xmlWriter]::create($out_file, $fmt)
			$doc.save($w)
		}finally{
			$w.close();
		}
	}
}

if($testMode){
	$dst_root = 'dummy'
}else{
	if($clean){
		remove-item 'Japanese' -recurse -errorAction ignore
		start-sleep -s 1 # avoid f*n useless buggy powershell's bug
	}
	$d = new-item 'Japanese' -itemType directory
	start-sleep -s 1 # avoid f*n useless buggy powershell's bug
	if(!$d){
		throw 'cannot careate directory'
	}
	$dst_root = resolve-path $d
}

if(($target -eq 'all') -or ($target -eq 'def')){
	$dst1 = join-path $dst_root 'DefInjected'
	get-childItem -literalPath 'core\DefInjected' -directory | foreach-object {
		$dir = $_
		$dst_dir = join-path $dst1 $dir.name
		if(!$testMode){
			mkdir -force $dst_dir | out-null
		}

		get-childItem -literalPath $dir.fullName -filter *.unko -file | foreach-object {
			$file = $_
			$out_file = join-path $dst_dir "$($file.baseName).xml"
			convert_unko_to_xml $file.fullName $out_file 'LanguageData' $false
		}
	}
}


if(($target -eq 'all') -or ($target -eq 'key')){
	$dst_dir = join-path $dst_root 'Keyed'
	if(!$testMode){
		mkdir $dst_dir -force | out-null
	}

	get-childItem -literalPath 'core\Keyed' -filter *.unko -file | foreach-object {
		$file = $_
		$out_path = join-path $dst_dir "$($file.baseName).xml"
		convert_unko_to_xml $file.fullName $out_path 'LanguageData' $false
	}
}

if((($target -eq 'all') -or ($target -eq 'back'))){
	$dst_dir = join-path $dst_root 'Backstories'
	if(!$testMode){
		mkdir $dst_dir -force | out-null
	}

	#copy-item 'core\Backstories\Backstories.xml' $dst_dir
	convert_unko_to_xml 'core\Backstories\Backstories.unko' "$($dst_dir)\Backstories.xml" 'BackstoryTranslations' $true
}

if(($target -eq 'all') -or ($target -eq 'strings')){
	if($testMode){
		$jp_path = 'core\Strings'
	}else{
		$jp_path = "$dst_root\Strings"

		copy-item -literalPath 'core\Strings' $dst_root -recurse -force
		copy-item -literalPath 'core\Strings\' $dst_root\Strings\English -recurse -force -filter *.unko

		function remove_empty_directories([string]$path)
		{
			get-childItem -literalPath $path -directory | foreach-object {
				remove_empty_directories($(join-path $path $_))
			}
			if($(get-childItem -literalPath $path | measure-object).count -eq 0){
				remove-item $path
			}
		}
		remove_empty_directories $dst_root\Strings\English
	}

	# modify *.unko files. English sub first.
	if(!$testMode){
		get-childItem -literalPath "$dst_root\Strings\English" -filter *.unko -recurse | foreach-object {
			$path = $_.fullName
			$result = new-object collections.arrayList
			get-content -encoding utf8 -literalPath $path | foreach-object {
				[int]$p = $_.indexOf(':')
				if($p -ge 0){
					[void]$result.add($_.subString(0, $p))
				}else{
					[void]$result.add($_)
				}
			}

			$new_path = [io.path]::ChangeExtension($path, "txt")
			add-content -literalPath $new_path -encoding utf8 $result
			remove-item $path
		}
	}
	get-childItem -literalPath $jp_path -filter *.unko -recurse | foreach-object {
		$file_name = $_.name
		$path = $_.fullName
		$result = new-object collections.arrayList

		get-content -encoding utf8 -literalPath $path | foreach-object {
			[int]$p = $_.indexOf(':')
			if($p -ge 0){
				try{
					$str = replace($_.subString($p + 1))
					[void]$result.add($str)
				}catch [myunko]{
					write-host "$($_): $($file_name)"
					if(!$testMode){
						exit
					}
				}
			}else{
				[void]$result.add($_)
			}
		}

		if(!$testMode){
			$new_path = [io.path]::ChangeExtension($path, "txt")
			add-content -literalPath $new_path -encoding utf8 $result
			remove-item $path
		}
	}
}

if(!$testMode -and ($target -eq 'all')){
	copy-item 'core\misc\*' $dst_root -force -recurse
}

if($target -eq 'all' -and !$testMode){
	foreach($word in $words.getEnumerator()) {
		$value = $word.value
		if($value.count -le 0){
			write-host Unused word:$($word.key)
		}
	}
}

}catch{
	$_.scriptStackTrace
	throw $_
}
