use Module::Build;
  my $build = Module::Build->new
    (
     module_name => 'Anna',
     license  => 'gpl',
     requires => {
                  'perl'				=> '5.8.8',
				  'File::Copy'			=> 0,
				  'GetOpt::Long'		=> 0,
				  'Carp'				=> 0,
				  'POE'					=> '0.9500',
				  'POE::Component::IRC'	=> '5.16',
				  'Term::ReadKey'		=> '2.30',
				  'HTML::Entities'		=> '1.35',
				  'DBI'					=> '1.52',
				  'DBD::SQLite'			=> '1.12',
				  'LWP::UserAgent'		=> '5.805'
                 },
	recommends => {
				   'Data::Dumper'		=> 0
				  },
	dist_author => 'Anders Ossowicki <and@vmn.dk>',
	dist_abstract => 'Anna^ is a small and lightweight IRC Bot',
	dist_version => '0.50',
	script_files => {
						'anna.pl'	=> 'Main script',
					}
    );
  $build->create_build_script;
