<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang='da' xml:lang='da'>
  <head>
    <meta http-equiv='Content-Type' content='text/html; charset=ISO-8859-15' />
    <title>Anna^ IRC Bot</title>
    <link rel='stylesheet' href='style.css' type='text/css' />
  </head>
  <body>
    <div id='page'>
      <div id='head'><h1>Anna^ <span class='title_alt'>IRC Bot</span></h1></div>
      <div id='sidebar'>
        <div class='sidebar_box'>
	  <div class='sidebar_box_head'>
	    <span class='sidebar_head'>Navigation</span>
	  </div>
	  <div class='sidebar_box_content'>
	    <a class='menu' href='./?p=home'>Home</a><br />
	    <a class='menu' href='./?p=about'>About</a><br />
	    <a class='menu' href='./?p=development'>Development</a><br />
	    <a class='menu' href='./?p=documentation'>Documentation</a><br />
	    <a class='menu' href='./?p=download'>Download</a><br />
	    <a class='menu' href='http://trac.frokostgruppen.dk/newticket?component=anna'>
	      Bugs
	    </a><br />
	    <a class='menu' href='http://git.frokostgruppen.dk/?p=anna.git'>
	      gitweb
	    </a><br />
	  </div>
        </div>
        <div id='banners'>
	  <p>
	    <a href='http://validator.w3.org/check?uri=referer'>
	      <img src='xhtml.png' alt='Valid XHTML 1.0 Strict' />
	    </a>
	  </p>
	  <p>
	    <a href='http://jigsaw.w3.org/css-validator/'>
	      <img src='css.png' alt='Valid CSS' />
	    </a>
	  </p>
        </div>
      </div>
      <div id='main'>
        <!-- Included content -->
        <?
        if ($_GET['p']) {
          if (file_exists($_GET['p'].".php")) {
            include_once($_GET['p'].'.php');
          } else {
            include_once('error.php');
          }
        } else {
          include_once('home.php');
        }
        ?>
        <!-- End of included content -->
      </div>
      <div id='footer'>
        <p>&copy; 2006-2008 <a href='mailto:and@vmn.dk'>Anders Ossowicki</a><br />
	Anna^ IRC Bot is free software; you can redistribute it and/or modify it 
	under the terms of the GNU General Public License as published by the 
	Free Software Foundation; version 2 of the License.</p>
      </div>
    </div>
  </body>
</html>
