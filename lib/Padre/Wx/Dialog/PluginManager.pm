package Padre::Wx::Dialog::PluginManager;
use strict;
use warnings;

use Padre::Wx         ();
use Padre::Wx::Dialog ();
use Wx::Locale        qw(:default);
use Data::Dumper qw(Dumper);

our $VERSION = '0.20';

sub get_layout {
	my ($plugins) = @_;
	$plugins ||= {};

	my @layout;
	foreach my $module (sort keys %$plugins) {
		push @layout,
			[
				['Wx::StaticText', undef, $module ],
				['Wx::Button',    "able_$module", 'na' ],
				['Wx::Button',    "pref_$module", gettext('Preferences') ],
			];
	}
	
	push @layout,
		[
			['Wx::Button',     'ok',     Wx::wxID_OK],
			[],
			[],
		];

	return \@layout;
}

sub dialog {
	my ($class, $main) = @_;

	my $config = Padre->ide->config;
	my @plugins = sort keys %{ $config->{plugins} };

	my $layout = get_layout( $config->{plugins} );
	my $dialog = Padre::Wx::Dialog->new(
		parent   => $main,
		title    => gettext('Plugin Manager'),
		layout   => $layout,
		width    => [300, 100, 100],
	);
	foreach my $module (@plugins) {
		Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}{"pref_$module"}, sub { _pref($_[0], $module)} );
		Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}{"able_$module"}, sub { _able($_[0], $module)} );
		$dialog->{_widgets_}{"pref_$module"}->Disable;
		_set_labels($dialog, $module, $config->{plugins}{$module}{enabled});
	}

	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}{ok},      sub { $dialog->EndModal(Wx::wxID_OK) } );
	$dialog->{_widgets_}{ok}->SetDefault;

	$dialog->{_widgets_}{ok}->SetFocus;

	return $dialog;
}

sub _pref {
	my ($self, $module) = @_;

	my $obj = Padre->ide->plugin_manager->plugins->{$module}{object};
	if ($obj and $obj->can('preferences_dialog')) {
		$obj->preferences_dialog;
	}
	
	#print "$self\n";
	return;
}

sub _able {
	my ($self, $module) = @_;
	
	my $config = Padre->ide->config;
	my $manager = Padre->ide->plugin_manager;
	
	if ($config->{plugins}{$module}{enabled}) {
		$config->{plugins}{$module}{enabled} = 0;
		$manager->unload_plugin($module);

	} else {
		$config->{plugins}{$module}{enabled} = 1;
		if (not $manager->reload_plugin($module)) {
			Padre->ide->wx->main_window->error($manager->{errstr});
		}
	}
	_set_labels($self, $module, $config->{plugins}{$module}{enabled});
	#print "$self\n";
	return;
}

sub _set_labels {
	my ($dialog, $module, $enabled) = @_;

	if ($enabled) {
		$dialog->{_widgets_}{"able_$module"}->SetLabel(gettext('Disable'));
		my $obj = Padre->ide->plugin_manager->plugins->{$module}{object};
		if ($obj and $obj->can('preferences_dialog')) {
			$dialog->{_widgets_}{"pref_$module"}->Enable;
		}
	} else {
		$dialog->{_widgets_}{"able_$module"}->SetLabel(gettext('Enable'));
		$dialog->{_widgets_}{"pref_$module"}->Disable;
	}
}

sub show {
	my ($class, $main) = @_;

	my $dialog   = $class->dialog($main);
	return if not $dialog->show_modal;
	
	my $data = $dialog->get_data;
	$dialog->Destroy;

	return;
}


1;
