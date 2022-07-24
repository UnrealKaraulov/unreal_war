<?php
require("nvault.class.php");

function prettyPrint($array) {
	echo '<pre>'.print_r($array, true).'</pre>';
}

$nvault = new nVault("test.vault");
echo prettyPrint($nvault);

?>
