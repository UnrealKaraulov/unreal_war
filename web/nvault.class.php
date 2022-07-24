<?php
class nVault {
	const magic = 0x6E564C54;
	const version = 0x0200;
	
	public $vault = array();
	private $endian = NULL;
	
	public function __construct($filename = NULL) {
		if(!is_null($filename)) {
			$error = $this->loadVault($filename);
			if($error != 1) return FALSE;
		}
	}

	public function loadVault($filename) {
		$vault = fopen($filename, 'rb');
		if(!$vault) return -1; // Unable to open vault file.
		
		$magic = fread($vault, 4);
		$littleEndian = unpack("V", $magic);
		$littleEndian = $littleEndian[1];
		$bigEndian = unpack("N", $magic);
		$bigEndian = $bigEndian[1];
		if($littleEndian == self::magic) $endian = TRUE;
		elseif($bigEndian == self::magic) $endian = FALSE;
		else return -2; // Magic does not conform;
		$this->endian = $endian;
		
		$version = unpack(($endian)?"v":"n", fread($vault, 2));
		$version = $version[1];
		if($version !== self::version) return -3; // Vault version does not conform.
		
		$entries = unpack(($endian)?"V":"N", fread($vault, 4));
		$entries = $entries[1];
		if(!is_int($entries)) return -4; // Entries information is malformed.
		
		for($i = 0; $i<$entries; $i++) {
			$timestamp = unpack(($endian)?"V":"N", fread($vault, 4));
			$timestamp = $timestamp[1];
			if(!is_int($timestamp)) continue;
			
			$keylen = unpack("C", fread($vault, 1));
			$keylen = $keylen[1];
			if(!is_int($keylen)) {
				continue;
			}
			$vallen = unpack(($endian)?"v":"n", fread($vault, 2));
			$vallen = $vallen[1];
			if(!is_int($vallen)) {
				continue;
			}
			
			$key = fread($vault, $keylen);
			$val = fread($vault, $vallen);
			
			$this->vault[] = array($key, $timestamp, $val);
		}
		
		return 1;
	}
	
	public function generateVault() {
		$magic = pack(($this->endian)?"V":"N", self::magic);
		$version = pack(($this->endian)?"v":"n", self::version);
		$entries = pack(($this->endian)?"V":"N", count($this->vault));
		
		$vault = $magic.$version.$entries;
		
		foreach($this->vault as $entry) {
			$timestamp = pack(($this->endian)?"V":"N", $entry[1]);
			$keylen = pack("C", strlen($entry[0]));
			$vallen = pack(($this->endian)?"v":"n", strlen($entry[2]));
			
			$vault .= $timestamp.$keylen.$vallen.$entry[0].$entry[2];
		}
		
		return $vault;
	}
}
?>
