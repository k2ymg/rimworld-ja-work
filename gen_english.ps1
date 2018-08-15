try{
$path_src_root = 'C:\Program Files (x86)\Steam\SteamApps\common\RimWorld'
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


function gen_defs($dst_dir, [xml.xmlNode]$parent_node)
{
	[collections.arrayList]$stack = $null
	[collections.arrayList]$result = $null

	function make_name($last_name)
	{
		$e = $stack.getEnumerator()
		$e.moveNext() | out-null
		$o = $e.current
		$w = new-object system.text.stringBuilder($o.m_name)
		while($e.moveNext()){
			$o = $e.current;
			[void]$w.append(".")
			if($o.m_li){
				[void]$w.append($o.m_index.toString('000'))
			}else{
				
				[void]$w.append($o.m_name)
			}
		}
		[void]$w.append(".")
		[void]$w.append($last_name)
		return $w.toString()
	}

	function gen_def_li([xml.xmlNode]$parent_node, $parent_name)
	{
		$index = 0
		$e = $parent_node.getEnumerator()
		while($e.moveNext()){
			$node = $e.current
			if($node.nodeType -eq [xml.xmlNodeType]::Text){
				continue
			}
			if($node.name -cne 'li'){
				continue
			}
			$name = $($parent_name + '.' + $index.toString('000'))
			[void]$result.add($name + ':' + $node.innerText)
			$index++
		}
	}

	function gen_def([xml.xmlNode]$parent_node)
	{
		$e = $parent_node.getEnumerator()
		while($e.moveNext()){
			$node = $e.current
			if($node.nodeType -eq [xml.xmlNodeType]::Text){
				continue
			}
			if($valid_names -ceq $node.name){
				$n = make_name $node.name
				if($node.hasChildNodes -and $node.firstChild.nodeType -ne [xml.XmlNodeType]::Text){
					# maybe rulesStrings
					gen_def_li $node $n
				}else{
					# some text contain raw line breaks so replace it.
					[void]$result.add($n + ':' + $node.innerText.replace("`n", '\n'))
				}
			}elseif($node.hasChildNodes){
				$index = 0
				$li = $false
				if($node.name -ceq 'li'){
					$li = $true
					$o = $stack[$stack.count - 1]
					$index = $o.m_index
					$o.m_index++
				}
				$o = new-object psobject -property @{m_name=$node.name; m_index=$index; m_li=$li}
				$stack.add($o) | out-null
				gen_def $node
				$stack.removeAt($stack.count - 1) | out-null
			}
		}
	}

	$e = $parent_node.getEnumerator()
	while($e.moveNext()){
		$node = $e.current
		$name = $null
		if($node.psobject.properties['Abstract'] -and $node.Abstract -eq 'True'){
			$name = $node.name
		}elseif($node.psobject.properties['defName']){
			$name = $node.defName
		}
		if(!$name){
			continue
		}
		$def = $node.localName

		$result = new-object collections.arrayList
		$stack = new-object collections.arrayList
		$o = new-object psobject -property @{m_name=$name; m_index=0; m_li=$false}
		$stack.add($o) | out-null
		gen_def $node

		if($result.count -gt 0){
			$path = join-path $dst_dir "$($def).unko"
			add-content -literalPath $path -encoding utf8 $result
		}
	}
}

function gen_def($dst_dir)
{
	$path = join-path $path_src_root 'Mods\Core\Defs'
	get-childItem -literalPath $path -filter *.xml -file -recurse | foreach-object {
		[xml]$doc = get-content -literalPath $_.fullName -encoding utf8

		if($doc.Defs){
			gen_defs $dst_dir $doc.Defs
		}
	}
}

function sort_def($dst_dir)
{
	get-childItem -literalPath $dst_dir -filter *.unko -file -recurse | foreach-object {
		get-content -literalPath $_.fullName -encoding utf8 | sort | set-content -literalPath $_.fullName -encoding utf8
	}
}

function copy_other($dst_dir)
{
	$path = join-path $path_src_root 'Mods\Core\Defs'
	copy-item -literalPath $path -destination $dst_dir\defs_xml -recurse

	$path = join-path $path_src_root 'Mods\Core\Languages\English'
	copy-item -literalPath $(join-path $path 'Keyed') -destination $dst_dir -recurse
	copy-item -literalPath $(join-path $path 'Strings') $dst_dir -recurse
}

$version = get_version
$dst_dir_root = new-item -path "en" -itemType directory -force
$dst_dir_root = new-item -path $(join-path $dst_dir_root $version) -itemType directory
$dst_dir_def = new-item -path $(join-path $dst_dir_root 'Def') -itemType directory

gen_def $dst_dir_def
sort_def $dst_dir_def
copy_other $dst_dir_root

}catch{
	$_.scriptStackTrace
	throw $_
}