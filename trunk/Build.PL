use Module::Build;
use File::Path;

my $class = Module::Build->subclass(code => <<'EOF');
	sub process_modules_files {
		my $self = shift;
		File::Path::mkpath(['blib/modules/core', 'blib/modules/auto']);
		system('cp -r modules/* blib/modules/');
	}
EOF

my $build = $class->new(
	module_name => 'Anna',
	license  => 'gpl',
	requires => {
		'perl'					=> '5.8.8',
		'File::Copy'			=> 0,
		'Getopt::Long'			=> 0,
		'Carp'					=> 0,
		'POE'					=> '0.9500',
		'POE::Component::IRC'	=> '5.16',
		'Term::ReadKey'			=> '2.30',
		'HTML::Entities'		=> '1.35',
		'DBI'					=> '1.52',
		'DBD::SQLite'			=> '1.12',
		'LWP::UserAgent'		=> '5.805'
	},
	recommends => {
		'Data::Dumper'	=> 0
	},
	dist_author => 'Anders Ossowicki <and@vmn.dk>',
	dist_abstract => 'Anna^ is a small and lightweight IRC Bot',
	dist_version => '0.50',
	script_files => {
		'anna.pl'	=> 'Main script',
	},
#	conf_files => { 'anna.conf' => 'conf/' },
#	modules_files => { 'modules/*' => 'modules/' },
	install_path => {
#		conf	=>	"/etc",
		modules =>	"/usr/share/anna/modules"
	}
);
#$build->add_build_element('conf');
$build->add_build_element('modules');
$build->create_build_script;
