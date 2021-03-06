<#
- エレメント名が衝突するので、.nameなどのプロパティを使わないこと。get_name()を使う。

親は処理できない。別のファイル、それこそCore、にあるかもしれないので。
親に対処するにはCoreどころか、MODを全部読んで一気にやらないといけない。

本当はやりたくはないが、親子関係を解決するために、全てのxmlからDefごとに抜き出す。
その後、ソートして、親を上に持っていき、unkoを作る。
#>
[cmdletBinding()]
param(
[validateSet('Core', 'Royalty')]
[string]$mod = 'Core',
[switch]$subdir,
[switch]$test
)

try{
$path_src_root = 'C:\Program Files (x86)\Steam\SteamApps\common\RimWorld\'
$path_data = join-path $path_src_root 'Data'
$path_mod = join-path $path_data $mod
$path_defs = join-path $path_mod 'Defs'
$path_lang_english = join-path $path_mod 'Languages\English'

$valid_names = get-content -literalPath 'valid_names.txt'

function get_version
{
	$s = get-content -literalPath $(join-path $path_src_root 'Version.txt')
	# liek: 1.0.1964 rev7 (development build)
	$p = $s.indexOf('(')
	if($p -ge 0){
		$s = $s.subString(0, $p)
	}
	$s.trim().replace(' ', '_')
}

if($mod -eq 'Core'){
	$version = get_version
}else{
	$version = get-date -format 'yyyy-MM-dd'
}
if(!$test){
	$dst_root = "en\$mod\$version"
	mkdir $dst_root | out-null
	$dst_root = resolve-path $dst_root

	$dst_dir_def = new-item -path $(join-path $dst_root 'DefInjected') -itemType directory
}

function replace_value($str)
{
	$str.replace("`r`n", '\n').replace("`n", '\n').replace("`r", '\n').replace("&gt;", '>').replace("&lt;", "<")
}

function write_def_child($sb, $depth, $children)
{
	foreach($child in $children){
		$name = $child.m_name

		if($child.m_children){
			[void]$sb.append("`t", $depth)
			[void]$sb.append('{')
			[void]$sb.appendLine($name)
			write_def_child $sb $($depth + 1) $child.m_children
			[void]$sb.append("`t", $depth)
			[void]$sb.appendLine('}')
		}else{
			if($child.m_value -is [array]){
				if($child.m_name -eq 'tips'){# special handle
					[void]$sb.append("`t", $depth)
					[void]$sb.append('{!')
					[void]$sb.appendLine($name)
					foreach($v in $child.m_value){
						[void]$sb.append("`t", $depth + 1)
						[void]$sb.append(':')
						[void]$sb.appendLine($(replace_value $v))
					}
				}else{
					[void]$sb.append("`t", $depth)
					[void]$sb.append('{?')
					[void]$sb.appendLine($name)
					foreach($v in $child.m_value){
						[void]$sb.append("`t", $depth + 1)
						[void]$sb.append(':')
						[void]$sb.appendLine($(replace_value $v))
					}
				}
				[void]$sb.append("`t", $depth)
				[void]$sb.appendLine('}')
			}else{
				[void]$sb.append("`t", $depth)
				[void]$sb.append($name)
				[void]$sb.append(':')
				[void]$sb.appendLine($(replace_value $child.m_value))
			}
		}
	}
}

function write_def($def_name, $name, $children, $abstract, $register_name)
{
	$sb = new-object system.text.stringBuilder
	[void]$sb.append('{')
	if($abstract){
		[void]$sb.append('$')
	}else{
		if($register_name){
			[void]$sb.append('%')
		}
	}
	[void]$sb.appendLine($name)
	write_def_child $sb 1 $children
	[void]$sb.appendLine('}')

	if(!$test){
		if($subdir){
			$path = join-path $dst_dir_def $def_name
			new-item -path $path -itemType directory -errorAction ignore | out-null
			$path = join-path $path "$($def_name).unko"
		}else{
			$path = join-path $dst_dir_def "$($def_name).unko"
		}
		add-content -literalPath $path -encoding utf8 $sb.toString() -noNewLine
	}
}

function replace_named_li($str)
{
	$n = $str

	for(;;){
		$i0 = $n.indexOf('{')
		if($i0 -lt 0){
			break
		}
		$i1 = $n.indexOf('}', $i0)
		if($i1 -lt 0){
			break
		}
		$n = $n.remove($i0, $i1 - $i0 + 1)
	}

	$n = $n.replace("’", '').replace(':', '').replace('-', '').replace("'", '').replace('(', '').replace(')', '').replace('+', '').trim()

	$n = $n -replace "\s+", '_'
	return $n
}

function alias_name($node)
{
	$name = $node.get_name()
	if($name -cne 'li'){
		return $name
	}

	$attr = $node.attributes['Class']

	if($node.parentNode.get_name() -eq 'comps'){
		# compsの下は、compClassがあればそれを使う
		$a = $node.childNodes | where-object {$_.get_name() -eq 'compClass'}
		if($a){
			return $a.get_innerText()
		}

		if($attr){
			$name = $attr.get_value()
			if($name.startsWith('HediffCompProperties_')){
				return $name.replace('HediffCompProperties_', 'HediffComp_')
			}
			if($name.startsWith('CompProperties_')){
				return $name.replace('CompProperties_', 'Comp')
			}
		}
	}

	if($node.parentNode.get_name() -eq 'hediffGivers'){
		$a = $node.childNodes | where-object {$_.get_name() -eq 'hediff'}
		if($a){
			return $a.get_innerText()
		}
	}

	if($attr){
		if($attr.get_value().startsWith('QuestNode_')){
			$name = $attr.value

			if($name -eq 'QuestNode_Signal'){
				$sig = $node.childNodes | where-object {$_.get_name() -eq 'inSignal'}
				if($sig){
					return $sig.innerText.replace('.', '')
				}
			}elseif($name -eq 'QuestNode_SubScript'){
				$a = $node.childNodes | where-object {$_.get_name() -eq 'def'}
				if($a){
					return $a.get_innerText()
				}
			}

			return $name.replace('QuestNode_', '')
		}
	}

	# priority Label > Def
	$a = $node.childNodes | where-object {$_.get_name() -eq 'label'}
	if($a){
		return replace_named_li $a.innerText
	}
	$a = $node.childNodes | where-object {$_.get_name() -eq 'customLabel'}
	if($a){
		return replace_named_li $a.innerText
	}
	$a = $node.childNodes | where-object {$_.get_name() -eq 'labelMale'}
	if($a){
		return replace_named_li $a.innerText
	}
	$a = $node.childNodes | where-object {$_.get_name() -eq 'def'}
	if($a){
		return $a.get_innerText()
	}

	$node.get_name()
}

function gen_def_li([xml.xmlNode]$parent_node)
{
	for($node = $parent_node.firstChild; $node; $node = $node.nextSibling){
		if($node.nodeType -eq [xml.xmlNodeType]::Text){
			continue
		}
		if($node.get_name() -cne 'li'){
			continue
		}
		$node.innerText
	}
}

function gen_def_options([xml.xmlNode]$parent_node)
{
	$index = 0
	for($node = $parent_node.firstChild; $node; $node = $node.nextSibling){
		if($node.nodeType -eq [xml.xmlNodeType]::Text){
			continue
		}
		new-object psobject -property @{m_name="$($index).slateRef"; m_children=$null; m_value=$node.innerText}
		$index++
	}
}

$QuestNode_Set_accepted = @('customLetterLabel', 'customLetterText', 'returnLetterText')
$g_tkey = $null

function gen_def_children([xml.xmlNode]$parent_node)
{
	$counter = @{}

	for($node = $parent_node.firstChild; $node; $node = $node.nextSibling){
		if($node.nodeType -eq [xml.xmlNodeType]::Text){
			continue
		}

		$name = alias_name $node

		if($counter.containsKey($name)){
			$c = $counter[$name]
			$c.m_count++
		}else{
			$c = new-object psobject -property @{m_count=1; m_index=0}
			[void]$counter.add($name, $c)
		}
	}

	$class_attr = $parent_node.attributes['Class']
	if($class_attr){
		if($class_attr.value -eq 'QuestNode_Set'){
			$nn = $parent_node.childNodes | where-object {$_.get_name() -eq 'name'}
			if($QuestNode_Set_accepted -ceq $nn.innerText){
				$v = $parent_node.childNodes | where-object {$_.get_name() -eq 'value'}
				new-object psobject -property @{m_name="$($v.get_name()).slateRef"; m_children=$null; m_value=$v.innerText}
			}
			return
		}
		<#if($class_attr.value -eq 'QuestNode_GetRandomElement'){
			for($node = $parent_node.firstChild; $node; $node = $node.nextSibling){
				if($node.nodeType -eq [xml.xmlNodeType]::Text){
					continue
				}
				if($node.get_name() -eq 'options'){
					$children = gen_def_options $node
					if($children){
						new-object psobject -property @{m_name=$node.get_name(); m_children=$children; m_value=$null}
					}
				}
			}
			return
		}#>
	}


	for($node = $parent_node.get_firstChild(); $node; $node = $node.get_nextSibling()){
		if($node.nodeType -eq [xml.xmlNodeType]::Comment){
			continue
		}
		if($node.nodeType -eq [xml.xmlNodeType]::Text){
			continue
		}

		$name = alias_name $node
		$children = $null
		$value = $null
		$name_suffix = $null

		$c = $counter[$name]
		if($c.m_count -gt 1){
			$c.m_index++
		}

		if($valid_names -ceq $node.get_name()){
			if($node.hasChildNodes -and $node.firstChild.nodeType -ne [xml.XmlNodeType]::Text){
				# rulesStrings or rulesFiles, maybe
				$value = @(gen_def_li $node)
				if(!$value){
					continue
				}
			}else{
				# eject exceptions
				if($class_attr){
					if(($node.get_name() -eq 'name') -and ($class_attr.value.startsWith('QuestNode_'))){
						continue
					}
				}

				if($class_attr){
					if($class_attr.value.startsWith('QuestNode_')){
						$name_suffix = 'slateRef'
					}
				}else{
					# QuestNode_/parms
					if(($name -eq 'customLetterLabel') -or ($name -eq 'customLetterText') -or ($name -eq 'arrivingPawnsLabelDef')){
						$name_suffix = 'value.slateRef'
					}
				}

				$tk = $node.attributes['TKey']
				if($tk){
					$name = $tk.value
					if($name_suffix){
						$name = "$($name).$($name_suffix)"
					}
					$a = new-object psobject -property @{m_name=$name; m_children=$null; m_value=$node.innerText}
					[void]$g_tkey.add($a)
					continue
				}

				$value = $node.innerText
			}
		}elseif($node.hasChildNodes){
			$tk = $node.attributes['TKey']
			if($tk){
				$a = new-object psobject -property @{m_name=$tk.value + '.slateRef'; m_children=$null; m_value=$node.innerXML}
				[void]$g_tkey.add($a)
				continue
			}

			$children = @(gen_def_children $node)
			if(!$children){
				continue
			}
		}else{

			continue
		}

		if($c.m_count -gt 1){
			$name = "$($name)-$($c.m_index - 1)"
		}
		if($name_suffix){
			$name = "$($name).$($name_suffix)"
		}
		new-object psobject -property @{m_name=$name; m_children=$children; m_value=$value}
	}
}

$abstracts = @{}

function gen_defs($parent_node)
{
	foreach($node in $parent_node){
		$def_name = $node.get_localName()

		$abstract = $false
		$name = $null
		$parent_name = $null
		$register_name = $null

		$a = $node.attributes['Abstract']
		if($a -and $a.value -eq 'True'){
			$abstract = $true
			$name = $node.attributes['Name'].value
			$register_name = $name
		}elseif($node.psobject.properties['defName']){
			$name = $node.defName
			$a = $node.attributes['Name']
			if($a){
				$register_name = $a.value
			}
		}
		if(!$name){
			continue
		}

		$a = $node.attributes['ParentName']
		if($a){
			$parent_name = $a.value
		}

		$g_tkey = new-object system.collections.arrayList
		$children = @(gen_def_children $node)
		if($g_tkey.count -gt 0){
			$children += $g_tkey
		}
		$g_tkey = $null

		if($children.count -gt 0){
			if($register_name){
				# 参照先名とDef名が異なる場合があるので、Def名にする
				$abstracts[$register_name] = $name
			}
			if($parent_name){
				$a = $abstracts[$parent_name]
				if($a){
					$a = new-object psobject -property @{m_name="$"; m_children=$null; m_value=$a}
					$children += $a
				}
			}
			write_def $def_name $name $children $abstract $register_name
		}else{
			if($parent_name){
				#write-host 'empty' $parent_name
				$a = $abstracts[$parent_name]
				if($a){
					#write-host 'hit' $parent_name
					$a = new-object psobject -property @{m_name="$"; m_children=$null; m_value=$a}
					write_def $def_name $name @($a) $abstract $register_name
					
					if($register_name){
						# 参照先名とDef名が異なる場合があるので、Def名にする
						$abstracts[$register_name] = $name
					}
				}
			}
		}
	}
}

function gather_def($result, $def, $parent_node)
{
	for($node = $parent_node.get_firstChild(); $node; $node = $node.get_nextSibling()){
		if($node.get_name() -ne $def){
			continue
		}
		[void]$result.add($node)
	}
}

function sort_def($defs)
{
	for($i = 0; $i -lt $defs.count - 1; $i++){
		$node = $defs[$i]

		$a = $node.attributes['ParentName']
		if(!$a){
			continue
		}
		$pn = $a.value

		for($j = $i + 1; $j -lt $defs.count; $j++){
			$node = $defs[$j]

			$a = $node.attributes['Name']
			if(!$a){
				continue
			}

			if($a.value -eq $pn){
				[array]::copy($defs, $i, $defs, $i + 1, $j - $i)
				$defs[$i] = $node
				$i--
				break
			}
		}
	}
}

$rs = new-object system.xml.xmlReaderSettings
$rs.ignoreComments = $true
$rs.ignoreWhitespace = $true

function gen_def_all
{
	$valid_def = get-content -literalPath 'valid_def.txt'

	foreach($def in $valid_def){
		write-host $def
		$defs = new-object system.collections.arrayList

		get-childItem -literalPath $path_defs -filter *.xml -file -recurse | foreach-object {
			$doc = $null

			$r = [system.xml.xmlReader]::create($_.fullName, $rs)
			try{
				$doc = new-object system.xml.xmlDocument
				$doc.load($r)
			}finally{
				$r.close()
			}

			if($doc.Defs){
				gather_def $defs $def $doc.Defs
			}
		}

		if($defs.count -gt 0){
			$defs = $defs.toArray()
			sort_def $defs

			gen_defs $defs
		}
	}
}

function copy_other
{
	copy-item -literalPath $path_defs -destination "$dst_root\defs_xml" -recurse

	$path = $path_lang_english
	copy-item -literalPath $(join-path $path 'Strings') $dst_root -recurse -errorAction ignore

	try{
		$src = resolve-path "$path\Strings"
		$dst = mkdir "$dst_root\strings_flat"
		$remove_len = $src.toString().length + 1
		get-childItem -literalPath $src -filter *.txt -file -recurse | foreach-object {
			$dst_name = $_.fullName.subString($remove_len).replace('\', '_')
			copy-item $_.fullName "$dst\$dst_name"
		}
	}catch [System.Management.Automation.ItemNotFoundException]{
	}
}

function gen_keyed
{
	if($test){
		$s = $null
	}else{
		mkdir "$dst_root\Keyed" -force | out-null
		$dst = "$dst_root\Keyed\Keyed.unko"
		$s = new-object system.io.streamWriter($dst, [system.text.encoding]::utf8)
	}

	try{
		get-childItem -literalPath "$path_lang_english\Keyed" -filter *.xml -file -recurse | foreach-object {

			$r = [system.xml.xmlReader]::create($_.fullName, $rs)
			try{
				$doc = new-object system.xml.xmlDocument
				$doc.load($r)
			}finally{
				$r.close()
			}

			$node = $doc.LanguageData
			for($node = $node.firstChild; $node; $node = $node.nextSibling){
				$name = $node.get_name()
				$value = $(replace_value $node.innerText)
				if($s){
					$s.write($name)
					$s.write(':')
					$s.writeLine($value)
				}
			}
		}
	}finally{
		if($s){
			$s.close()
		}
	}
}


gen_def_all
if(!$test){
	copy_other
}
gen_keyed

}catch{
	$_.scriptStackTrace
	throw $_
}
