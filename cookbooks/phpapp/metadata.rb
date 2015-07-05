name             'phpapp'
maintainer       'origigi'
maintainer_email 'joseph@origigi.biz'
license          'All rights reserved'
description      'Installs/Configures phpapp'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

depends "apache2"
depends "php-fpm"
