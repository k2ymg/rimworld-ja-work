[cmdletBinding()]
param(

[validateSet('all', 'def', 'back', 'key', 'strings')]
[string]$target = 'all',

[validateSet('Core', 'Royalty')]
[string]$mod = 'Core',

[validateSet('a','b', 'c')]
[string]$trans = 'a',

[switch]$readable,
[switch]$clean,
[switch]$test,
[switch]$unused,
[switch]$hankaku
)

try{

# XMLやStreamReaderなどは相対パスを認識しないので、絶対パスに直す
$src_root = resolve-path "mod\$mod"
$dst_root = "jp\$mod\Japanese"
if(!$test){
	mkdir $dst_root -force | out-null
	# resolve-pathは存在チェックがあるので、mkdirの後ろで行うこと
	$dst_root = resolve-path $dst_root
}

$write_format = new-object system.xml.xmlWriterSettings
if($readable){
	$write_format.indent = $true
	$write_format.IndentChars = ''
}else{
	$write_format.indent = $false
}


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
	[bool] $m_index_mode
	[int] $m_index_count
	$m_element

	ctx()
	{
		$this.m_name = $null
		$this.m_li_mode = $false
		$this.m_index_mode = $false
		$this.m_index_count = 0
	}
	ctx([string]$name)
	{
		$this.m_name = $name
		$this.m_li_mode = $false
		$this.m_index_mode = $false
		$this.m_index_count = 0
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

	if($local_words){
		$r = $local_words[$key]
	}else{
		$r = $null
	}
	if(!$r){
		$r = $words[$key]
		if(!$r){
			throw [myunko]"key not found:$($key)"
		}
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
		throw [myunko]"not found '$t1'"
	}

	& $r $str $p0 $p1
}

function replace_sub_switch([string]$str, [int]$p0, [string]$t1, $r)
{
	[int]$p1 = -1
	[int]$p2 = -1

	$p1 = $str.indexOf($t1, $p0 + 2)
	if($p1 -lt 0){
		throw [myunko]"not found '$t1'"
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

	# 本当は、頭から1文字ずつつ調べないといけないが、保留。
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

	<#
	$t = $str.indexOf('>')
	if($t -ge 0){
		if(-not (($t -gt 0) -and ($str[$t - 1] -eq '-'))){
			throw [myunko]"Error: included >: $($str)"
		}
	}
	$t = $str.indexOf('<')
	if($t -ge 0){
		throw [myunko]"Error: included <: $($str)"
	}#>

	#$str = $str.replace('//', '`u{200b}') #faq. zero-width space not work

	#if($str -ne $str.trim()){
	#	throw [myunko]"contain lead or last space: $($str)"
	#}
	$str
}

function make_word($file_path, $file_name)
{
	[int]$line_no = 0

	get-content -literalPath $file_path -encoding utf8 | foreach-object {
		$line_no++

		if(!$_ -or $_.startsWith(';')){
			return
		}

		$p = $_.indexOf(':')
		if($p -lt 0){
			"{0} ({1}): no separator ':'" -f $file_name, $line_no | write-host
			$script:error_stop = $true
			return
		}
		$key = $_.subString(0, $p)
		$value = $_.subString($p + 1)

		if(!$value){
			"{0} ({1}): value is empty" -f $file_name, $line_no | write-host
			$script:error_stop = $true
		}else{
			if($value -ne $value.trim()){
				"{0} ({1}): value contains lead or trail space" -f $file_name, $line_no | write-host
				$script:error_stop = $true
			}
			if($value.indexOf(':') -ge 0){
				"{0} ({1}): value contains separator ':'" -f $file_name, $line_no | write-host
				$script:error_stop = $true
			}
		}

		if($words.containsKey($key)){
			"{0} ({1}): duplicate value '{2}'" -f $file_name, $line_no, $key | write-host
			$script:error_stop = $true
		}else{
			$o = new-object psobject -property @{value=$value; count=0}
			[void]$words.add($key, $o)
		}
	}
}

function make_words
{
	get-childItem -literalPath 'words2' -filter *.unko -file | foreach-object {
		make_word $_.fullName $_.name
	}

	get-childItem -literalPath "words2\$mod" -filter *.unko -file -errorAction ignore | foreach-object {
		make_word $_.fullName $_.name
	}
}

function replace_words
{
	foreach($word in $words.getEnumerator()) {
		try{
			$word.value.value = replace($word.value.value)
		}catch [myunko]{
			write-host "Error: $($_): key=$($word.key)"
			if(!$test){
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

	#exception
	if($x -eq 'options'){
		return $true
	}
	if($x -eq 'value'){
		return $true
	}
	if($x -eq 'slateRef'){
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

$words = @{}
$local_words = $null
make_words | out-null
if($error_stop){
	exit
}

replace_words | out-null
if($error_stop){
	exit
}


function check_bracket($str)
{
	[int]$i = $str.indexOfAny('{}[]')
	while($i -ge 0){
		$b0 = $str[$i]

		if($b0 -in '}', ']'){
			'open-bracket {0}: {1}' -f $b0, $str | write-host
			return
		}

		if($b0 -eq '{'){
			if(($i + 1 -lt $str.length) -and ($str[$i + 1] -eq '{')){
				$b0 = '{{'
				$i++
			}
		}

		$i = $str.indexOfAny('{}[]', $i + 1)
		if($i -lt 0){
			'unclosed bracket {0}: {1}' -f $b0, $str | write-host
			return
		}

		$b1 = $str[$i]
		if($b1 -eq '}'){
			if(($i + 1 -lt $str.length) -and ($str[$i + 1] -eq '}')){
				$b1 = '}}'
				$i++
			}
		}

		if(
			($b0 -eq '{') -and ($b1 -ne '}') -or
			($b0 -eq '[') -and ($b1 -ne ']') -or
			($b0 -eq '{{') -and ($b1 -ne '}}')
		){
			'unmatched bracket {0} {1}: {2}' -f $b0, $b1, $str | write-host
			return
		}

		$i = $str.indexOfAny('{}[]', $i + 1)
	}
}

function replace_value($str)
{
	#$str#$str.replace('<', '&lt;').replace('>', '&gt;')
	if($hankaku){
		$str.replace('。', '｡').replace('、', '､').replace('「', '｢').replace('」', '｣')
	}else{
		$str
	}

	check_bracket $str
}

function merge_block($block, $block_parent)
{
	foreach($c in $block_parent.m_children){
		$a = $block.m_children | where-object {$_.m_name -eq $c.m_name}
		if($a){
			if($c.m_is_block){
				merge_block $a $c
			}
		}else{
			[void]$block.m_children.add($c)
		}
	}
}

function gen_xml_block($parent, $add_to_child, $block, $parent_name)
{
	[int]$index = 0

	if($parent_name){
		$parent_name = "{0}.{1}" -f $parent_name, $block.m_name
	}else{
		$parent_name = $block.m_name
	}

	if($add_to_child -or ($block.m_mode -eq 1)){
		if($add_to_child){
			$name = $block.m_name
		}else{
			$name = $parent_name
		}
		$e = $doc.createElement($name)
		[void]$parent.appendChild($e)
		$parent = $e
	}

	foreach($b in $block.m_children){
		if($b.m_is_block){
			gen_xml_block $parent $add_to_child $b $parent_name
		}else{
			if($block.m_mode -eq 2){
				if($add_to_child){
					$name = "{0}" -f $index
				}else{
					$name = "{0}.{1}" -f $parent_name, $index
				}
				$index++
			}elseif($block.m_mode -eq 1){
				$name = 'li'
			}else{
				if($add_to_child){
					$name = $b.m_name
				}else{
					$name = "{0}.{1}" -f $parent_name, $b.m_name
				}
			}
			$e = $doc.createElement($name)
			if($b.m_value){
				$e.innerText = replace_value $b.m_value
			}
			[void]$parent.appendChild($e)
		}
	}
}

function gen_xml($file_name, $s, $doc_root, $add_to_child)
{
	[int]$line_no = 0

	$abstracts = @{}

	$local_words = @{}

	$block = $null
	$block_stack = new-object system.collections.stack

	for(;;){
		$line = $s.readLine()
		if($line -eq $null){
			break
		}

		$line_no++
		$line = $line.trim()
		if(!$line -or $line.startsWith(';')){
			continue
		}

		# begin block
		if($line.startsWith('{')){
			$name = $line.subString(1)
			$mode = 0
			[int]$abs = 0

			if($name.startsWith('$')){
				if($block_stack.count -ge 1){
					"{0} ({1}): not allow '$' in sub block" -f $file_name, $line_no | write-host
					return
				}

				$name = $name.subString(1)
				$abs = 1
				
			}

			if($name.startsWith('%')){
				if($block_stack.count -gt 1){
					"{0} ({1}): not allow '%' in sub block" -f $file_name, $line_no | write-host
					return
				}

				$name = $name.subString(1)
				$abs = 2
			}

			if($name.startsWith('?')){
				$name = $name.subString(1)
				$mode = 1
			}
			if($name.startsWith('!')){
				$name = $name.subString(1)
				$mode = 2
			}

			[void]$block_stack.push($block)
			$new_block = new-object psobject -property @{ `
				m_is_block=$true; m_abs=$abs; m_name=$name; m_mode=$mode; m_children=$(new-object system.collections.arrayList)}
			if($block){
				[void]$block.m_children.add($new_block)
			}
			$block = $new_block
			continue
		}

		# end block
		if($line.startsWith('}')){
			if($block_stack.count -le 0){
				"{0} ({1}): not match pair of '{{'" -f $file_name, $line_no | write-host
				return
			}

			if($block_stack.count -eq 1){
				if($block.m_abs -eq 1){
					[void]$abstracts.add($block.m_name, $block)
				}elseif($block.m_abs -eq 2){
					[void]$abstracts.add($block.m_name, $block)
					gen_xml_block $doc_root $add_to_child $block $null
				}else{
					gen_xml_block $doc_root $add_to_child $block $null
				}
			}else{
				if($block.m_name -eq 'BaseBear'){
					write-host 'mode' $block.m_abs $block_stack.count
				}
			}

			$block = $block_stack.pop()
			continue
		}

		# name:value, maybe
		if($line.startsWith('@')){
			if($block){
				"{0} ({1}): not allow '@' inside block" -f $file_name, $line_no | write-host
			}

			$line = $line.subString(1)
			$p0 = $line.indexOf(':')
			if($p0 -lt 0){
				"{0} ({1}): not found name-value separator ':'" -f $file_name, $line_no | write-host
				return
			}

			$name = $line.subString(0, $p0)
			$value = $line.subString($p0 + 1)

			if($local_words.containsKey($name) -or $words.containsKey($name)){
				"{0} ({1}): duplicate value '{2}'" -f $file_name, $line_no, $name | write-host
			}else{
				$o = new-object psobject -property @{value=$value; count=0}
				[void]$local_words.add($name, $o)
			}

			continue
		}

		$p0 = $line.indexOf(':')
		if($p0 -lt 0){
			"{0} ({1}): not found name-value separator ':'" -f $file_name, $line_no | write-host
			return
		}

		$name = $line.subString(0, $p0)
		if($name){
			if($block -and ($block.m_mode -ne 0)){
				"{0} ({1}): the name must be empty in LI mode" -f $file_name, $line_no | write-host
				return
			}
		}

		$value = $line.subString($p0 + 1)

		if($name.startsWith('$')){
			if(!$block){
				"{0} ({1}): not allow '$' at root" -f $file_name, $line_no | write-host
				return
			}

			$abs_block = $abstracts[$value]
			if($abs_block){
				merge_block $block $abs_block
			}else{
				"{0} ({1}): not found '$' key '{2}'" -f $file_name, $line_no, $value | write-host
				#return
			}

			continue
		}

		try{
			$value = replace $value
		}catch [myunko] {
			"{0} ({1}): {2}" -f $file_name, $line_no, $_.toString() | write-host
		}

		<#if(!$block -or ($block.m_mode -eq 0)){
			try{
				[void][system.xml.xmlConvert]::VerifyName($name);
			}catch{
				"{0} ({1}): {2}" -f $file_name, $line_no, $_ | write-host
				return
			}
		}#>

		if(!$(valid_name $name)){
			"{0} ({1}): unregistered name '{2}'" -f $file_name, $line_no, $name | write-host
			return
		}

		if($block){
			$new_value = new-object psobject -property @{ `
				m_is_block=$false; m_name=$name; m_value=$value}
			[void]$block.m_children.add($new_value)
		}else{
			try{
				[void][system.xml.xmlConvert]::VerifyName($name);
			}catch{
				"{0} ({1}): {2}" -f $file_name, $line_no, $_ | write-host
				return
			}
			$e = $doc.createElement($name)
			if($value){
				$e.innerText = replace_value $value
			}
			[void]$root.appendChild($e)
		}
	}

	if($block_stack.count -gt 0){
		"{0} : Unclosed block" -f $file_name | write-host
	}

}

function special_senario_def($root, $doc)
{
	# *.label -> *.senario.name
	# *.description -> *.senario.description
	$result = new-object system.collections.arrayList
	$names = @('label', 'description')

	foreach($item in $root.get_childNodes()){
		$parts = $item.get_name().split('.')

		if($parts.count -ne 2){
			continue
		}
		if(!($names -eq $parts[1])){
			continue
		}
		if($parts[1] -eq 'label'){
			$parts[1] = 'name'
		}
		$e = $doc.createElement($("{0}.scenario.{1}" -f $parts[0], $parts[1]))
		$e.innerText = $item.innerText

		[void]$result.add($e)
	}

	$result | foreach-object {[void]$root.appendChild($_)}
}

function special_skill_def($root, $doc)
{
	# *.skillLabel -> *.label
	$result = new-object system.collections.arrayList

	foreach($item in $root.get_childNodes()){
		$parts = $item.get_name().split('.')

		if($parts.count -ne 2){
			continue
		}
		if($parts[1] -ne 'skillLabel'){
			continue
		}
		$e = $doc.createElement($("{0}.label" -f $parts[0]))
		$e.innerText = $item.innerText

		[void]$result.add($e)
	}

	$result | foreach-object {[void]$root.appendChild($_)}
}

function unko_to_xml([string]$src, [string]$dst, [string]$root_node_name, [bool]$direct_child, $file_name)
{
	$doc = new-object system.xml.xmlDocument
	$doc.appendChild($doc.createXmlDeclaration("1.0", "UTF-8", $null)) | out-null
	$root = $doc.appendChild($doc.createElement($root_node_name))

	$s = new-object system.io.streamReader($src, [system.text.encoding]::utf8)
	try{
		gen_xml $file_name $s $root $direct_child
	
		if($file_name -eq 'ScenarioDef'){
			special_senario_def $root $doc
		}
		if($file_name -eq 'SkillDef'){
			special_skill_def $root $doc
		}

	}finally{
		$s.close()
	}

	if(!$test){
		$w = [system.xml.xmlWriter]::create($dst, $write_format)
		try{
			$doc.save($w)
		}finally{
			$w.close();
		}
	}
}


# DefInjected
if(($target -eq 'all') -or ($target -eq 'def')){
	$dst_def = "$dst_root\DefInjected"
	get-childItem -literalPath "$src_root\DefInjected" -file -filter *.unko | foreach-object {
		$src = $_.fullName
		$dst_dir = join-path $dst_def $_.baseName
		if(!$test){
			mkdir -force $dst_dir | out-null
		}
		$dst = join-path $dst_dir "$($_.baseName).xml"

		unko_to_xml $src $dst 'LanguageData' $false $_.baseName
	}
}


# Keyed
if(($target -eq 'all') -or ($target -eq 'key')){
	$dst_dir = join-path $dst_root 'Keyed'
	if(!$test){
		mkdir $dst_dir -force | out-null
	}

	get-childItem -literalPath $(join-path $src_root 'Keyed') -filter *.unko -file | foreach-object {
		$src = $_.fullName
		$dst = join-path $dst_dir "$($_.baseName).xml"
		unko_to_xml $src $dst 'LanguageData' $false $_.baseName
	}
}


# Backstories
if(($mod -eq 'Core') -and (($target -eq 'all') -or ($target -eq 'back'))){
	$src = join-path $(join-path $src_root 'Backstories') 'Backstories.unko'

	$dst_dir = join-path $dst_root 'Backstories'
	if(!$test){
		mkdir $dst_dir -force | out-null
	}
	$dst = join-path $dst_dir 'Backstories.xml'

	unko_to_xml $src $dst 'BackstoryTranslations' $true 'Backstories'
}


# Strings
if(($mod -eq 'Core') -and (($target -eq 'all') -or ($target -eq 'strings'))){
	if($test){
		$jp_path = 'mod\core\Strings'
	}else{
		$jp_path = "$dst_root\Strings"

		copy-item -literalPath "$src_root\Strings" $dst_root -recurse -force
		copy-item -literalPath "$src_root\Strings\" $dst_root\Strings\English -recurse -force -filter *.unko

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
	if(!$test){
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
			set-content -literalPath $new_path -encoding utf8 $result
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
					if(!$test){
						exit
					}
				}
			}else{
				[void]$result.add($_)
			}
		}

		if(!$test){
			$new_path = [io.path]::ChangeExtension($path, "txt")
			set-content -literalPath $new_path -encoding utf8 $result
			remove-item $path
		}
	}
}

# other
if($mod -eq 'Core'){
	if(!$test -and ($target -eq 'all')){
		copy-item 'core\misc\*' $dst_root -force -recurse
	}
}

if($unused){
	foreach($word in $words.getEnumerator()) {
		$value = $word.value
		if($value.count -eq 0){
			"unused: {0}" -f $word.key | write-host
		}
	}
}

}catch{
	$_.scriptStackTrace
	throw $_
}
