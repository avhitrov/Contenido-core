BEGIN { require 'inc.pl' };

use strict;

use Contenido::Globals;
use Contenido::Init;
$Contenido::Init::DEBUG = 0;
Contenido::Init->init();

1;
