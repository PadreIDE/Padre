package Padre::Wx::Dialog::ConfigSync;

use 5.008;
use strict;
use warnings;
use Padre::Wx                  ();
use Padre::Wx::Dialog          ();
use Padre::Wx::Role::MainChild ();
use Padre::Locale              ();

our $VERSION = '0.68';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::Dialog
};

=pod

=head1 NAME

Padre::Wx::Dialog::ConfigSync - A Dialog for interacting with ConfigSync
This is an initial version generated partially by wxGlade. A rewrite is 
in order to align with Padre.

=cut

# things to note - certain elements interact with the $config_sync object
# to update state. Ie user logged in / not logged in
# certain messages are defined in the Padre::ConfigSync class, this is most definitely
# not the proper location for such things

sub new {
	my $class  = shift;
	my $main   = shift;
	my $config = $main->config; 
	my $sync   = $main->ide->config_sync;

	# Create the Wx dialog
	my $self = $class->SUPER::new(
		$main,
		-1,
		Wx::gettext('Padre ConfigSync'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxCAPTION
		| Wx::wxCLOSE_BOX
		| Wx::wxSYSTEM_MENU
	);

	$self->{Notebook} = Wx::Notebook->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		0,
	);
	$self->{Help_Pane} = Wx::Panel->new(
		$self->{Notebook},
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{Settings_Pane} = Wx::Panel->new(
		$self->{Notebook},
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{Sync_Pane} = Wx::Panel->new(
		$self->{Notebook},
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{Register_Pane} = Wx::Panel->new(
		$self->{Notebook},
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{Login_Pane} = Wx::Panel->new(
		$self->{Notebook},
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{lbl_status_static} = Wx::StaticText->new(
		$self->{Login_Pane},
		-1,
		"Status:",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxALIGN_CENTRE,
	);
	$self->{lbl_status} = Wx::StaticText->new(
		$self->{Login_Pane},
		-1,
		$sync->english_status,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{lbl_login} = Wx::StaticText->new(
		$self->{Login_Pane},
		-1,
		"Login:",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{txt_login} = Wx::TextCtrl->new(
		$self->{Login_Pane},
		-1,
		$config->config_sync_username ? $config->config_sync_username : '',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{lbl_password} = Wx::StaticText->new(
		$self->{Login_Pane},
		-1,
		"Password:",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{txt_password} = Wx::TextCtrl->new(
		$self->{Login_Pane},
		-1,
		$config->config_sync_password ? $config->config_sync_password : '',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_PASSWORD 
	);
	$self->{btn_login} = Wx::Button->new(
		$self->{Login_Pane},
		-1,
		$main->ide->config_sync->{state} eq 'logged_in' ? 'Log out' : 'Log in',
	);
	$self->{lbl_info} = Wx::StaticText->new(
		$self->{Register_Pane},
		-1,
		"Enter information below to register with ConfigSync!",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{lbl_username} = Wx::StaticText->new(
		$self->{Register_Pane},
		-1,
		"Username:",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{txt_username} = Wx::TextCtrl->new(
		$self->{Register_Pane},
		-1,
		"",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{lbl_pw1} = Wx::StaticText->new(
		$self->{Register_Pane},
		-1,
		"Password:",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{txt_pw} = Wx::TextCtrl->new(
		$self->{Register_Pane},
		-1,
		"",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_PASSWORD
	);
	$self->{lbl_pw2} = Wx::StaticText->new(
		$self->{Register_Pane},
		-1,
		"Password:",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{txt_pw_confirm} = Wx::TextCtrl->new(
		$self->{Register_Pane},
		-1,
		"",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_PASSWORD
	);
	$self->{lbl_email1} = Wx::StaticText->new(
		$self->{Register_Pane},
		-1,
		"Email:",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{txt_email} = Wx::TextCtrl->new(
		$self->{Register_Pane},
		-1,
		"",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{lbl_email2} = Wx::StaticText->new(
		$self->{Register_Pane},
		-1,
		"Email:",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{txt_email_confirm} = Wx::TextCtrl->new(
		$self->{Register_Pane},
		-1,
		"",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{btn_register} = Wx::Button->new(
		$self->{Register_Pane},
		-1,
		"Register",
	);
	$self->{lbl_status_b} = Wx::StaticText->new(
		$self->{Sync_Pane},
		-1,
		"Status:",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{lbl_status_info} = Wx::StaticText->new(
		$self->{Sync_Pane},
		-1,
		$sync->english_status,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{btn_local} = Wx::Button->new(
		$self->{Sync_Pane},
		-1,
		"Upload local config\n to server",
	);
	$self->{btn_remote} = Wx::Button->new(
		$self->{Sync_Pane},
		-1,
		"Download server config\n to local machine",
	);
	$self->{btn_delete} = Wx::Button->new(
		$self->{Sync_Pane},
		-1,
		"Delete server copy",
	);
	$self->{lbl_remote_server} = Wx::StaticText->new(
		$self->{Settings_Pane},
		-1,
		"Remote Server:",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{txt_remote} = Wx::TextCtrl->new(
		$self->{Settings_Pane},
		-1,
		$config->config_sync_server ? $config->config_sync_server : '',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{lbl_help} = Wx::StaticText->new(
		$self->{Help_Pane},
		-1,
		"This should contain a helpful message for how to use the system",
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
	);
	$self->{btn_ok} = Wx::Button->new(
		$self,
		Wx::wxID_OK,
		"",
	);
	$self->{btn_cancel} = Wx::Button->new(
		$self,
		Wx::wxID_CANCEL,
		"",
	);
	$self->SetTitle("Padre ConfigSync");
	$self->SetSize(
		$self->ConvertDialogSizeToPixels(Wx::Size->new(208,
		184)),
	);
	$self->{txt_login}->SetMinSize(
		Wx::Size->new(160,
		23),
	);
	$self->{txt_password}->SetMinSize(
		Wx::Size->new(160,
		23),
	);
	$self->{txt_username}->SetMinSize(
		Wx::Size->new(160,
		23),
	);
	$self->{txt_pw}->SetMinSize(
		Wx::Size->new(160,
		23),
	);
	$self->{txt_pw_confirm}->SetMinSize(
		Wx::Size->new(160,
		23),
	);
	$self->{txt_email}->SetMinSize(
		Wx::Size->new(160,
		23),
	);
	$self->{txt_email_confirm}->SetMinSize(
		Wx::Size->new(160,
			23),
	);
	$self->{txt_remote}->SetMinSize(
		Wx::Size->new(160,
			23),
	);


	my $sizer_1  = Wx::BoxSizer->new(Wx::wxVERTICAL);
	my $sizer_2  = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	my $sizer_3  = Wx::BoxSizer->new(Wx::wxVERTICAL);
	my $sizer_4  = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	my $sizer_5  = Wx::BoxSizer->new(Wx::wxVERTICAL);
	my $sizer_6  = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	my $sizer_7  = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	my $sizer_8  = Wx::BoxSizer->new(Wx::wxVERTICAL);
	my $sizer_9  = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	my $sizer_10 = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	my $sizer_11 = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	my $sizer_12 = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	my $sizer_13 = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	my $sizer_14 = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	my $sizer_15 = Wx::BoxSizer->new(Wx::wxVERTICAL);
	my $sizer_19 = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	my $sizer_20 = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	my $sizer_21 = Wx::BoxSizer->new(Wx::wxHORIZONTAL);

	$sizer_3->Add($self->{lbl_status_static}, 0, Wx::wxALL, 12);
	$sizer_3->Add($self->{lbl_status}, 0, Wx::wxLEFT, 30);
	$sizer_4->Add($self->{lbl_login}, 0, Wx::wxLEFT | Wx::wxRIGHT | Wx::wxTOP, 12);
	$sizer_4->Add($self->{txt_login}, 0, Wx::wxLEFT | Wx::wxTOP, 10);
	$sizer_3->Add($sizer_4, 0, 0, 0);
	$sizer_9->Add($self->{lbl_password}, 0, Wx::wxLEFT | Wx::wxRIGHT | Wx::wxTOP, 5);
	$sizer_9->Add($self->{txt_password}, 0, 0, 0);
	$sizer_8->Add($sizer_9, 0, Wx::wxLEFT | Wx::wxEXPAND, 0);
	$sizer_10->Add(150, 20, 0, 0, 0);
	$sizer_10->Add($self->{btn_login}, 0, Wx::wxLEFT | Wx::wxTOP, 5);
	$sizer_8->Add($sizer_10, 1, 0, 0);
	$sizer_7->Add($sizer_8, 1, Wx::wxEXPAND, 0);
	$sizer_3->Add($sizer_7, 0, Wx::wxEXPAND, 0);
	$self->{Login_Pane}->SetSizer($sizer_3);
	$sizer_5->Add($self->{lbl_info}, 0, Wx::wxALL, 15);
	$sizer_6->Add($self->{lbl_username}, 0, 0, 0);
	$sizer_6->Add($self->{txt_username}, 0, 0, 0);
	$sizer_5->Add($sizer_6, 0, Wx::wxLEFT | Wx::wxEXPAND, 10);
	$sizer_11->Add($self->{lbl_pw1}, 0, 0, 0);
	$sizer_11->Add($self->{txt_pw}, 0, 0, 0);
	$sizer_5->Add($sizer_11, 0, Wx::wxLEFT | Wx::wxEXPAND, 10);
	$sizer_12->Add($self->{lbl_pw2}, 0, 0, 0);
	$sizer_12->Add($self->{txt_pw_confirm}, 0, 0, 0);
	$sizer_5->Add($sizer_12, 0, Wx::wxLEFT | Wx::wxEXPAND, 10);
	$sizer_13->Add($self->{lbl_email1}, 0, 0, 0);
	$sizer_13->Add($self->{txt_email}, 0, Wx::wxLEFT, 25);
	$sizer_5->Add($sizer_13, 0, Wx::wxLEFT | Wx::wxEXPAND, 10);
	$sizer_14->Add($self->{lbl_email2}, 0, 0, 0);
	$sizer_14->Add($self->{txt_email_confirm}, 0, Wx::wxLEFT, 25);
	$sizer_5->Add($sizer_14, 0, Wx::wxLEFT | Wx::wxBOTTOM | Wx::wxEXPAND, 10);
	$sizer_5->Add($self->{btn_register}, 0, Wx::wxLEFT, 130);
	$self->{Register_Pane}->SetSizer($sizer_5);
	$sizer_15->Add($self->{lbl_status_b}, 0, Wx::wxLEFT | Wx::wxTOP | Wx::wxBOTTOM, 10);
	$sizer_15->Add($self->{lbl_status_info}, 0, Wx::wxLEFT | Wx::wxBOTTOM, 20);
	$sizer_19->Add($self->{btn_local}, 0, Wx::wxEXPAND, 0);
	$sizer_19->Add($self->{btn_remote}, 0, Wx::wxEXPAND, 0);
	$sizer_19->Add($self->{btn_delete}, 0, Wx::wxEXPAND, 0);
	$sizer_15->Add($sizer_19, 1, Wx::wxALIGN_CENTER_HORIZONTAL, 0);
	$self->{Sync_Pane}->SetSizer($sizer_15);
	$sizer_20->Add($self->{lbl_remote_server}, 0, Wx::wxALL, 10);
	$sizer_20->Add($self->{txt_remote}, 0, Wx::wxTOP, 5);
	$self->{Settings_Pane}->SetSizer($sizer_20);
	$sizer_21->Add($self->{lbl_help}, 0, Wx::wxALL, 15);
	$self->{Help_Pane}->SetSizer($sizer_21);
	$self->{Notebook}->AddPage($self->{Login_Pane}, "Login");
	$self->{Notebook}->AddPage($self->{Register_Pane}, "Register");
	$self->{Notebook}->AddPage($self->{Sync_Pane}, "Sync");
	$self->{Notebook}->AddPage($self->{Settings_Pane}, "Settings");
	$self->{Notebook}->AddPage($self->{Help_Pane}, "Help");
	$sizer_1->Add($self->{Notebook}, 1, Wx::wxEXPAND, 0);
	$sizer_2->Add($self->{btn_ok}, 0, 0, 0);
	$sizer_2->Add($self->{btn_cancel}, 0, Wx::wxLEFT, 10);
	$sizer_1->Add($sizer_2, 0, Wx::wxALL | Wx::wxALIGN_RIGHT, 5);
	$self->SetSizer($sizer_1);

	# event handlers
	Wx::Event::EVT_BUTTON(
		$self,
		$self->{btn_login},
		sub {
			$_[0]->btn_login;
		},
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{btn_register},
		sub {
			$_[0]->btn_register;
		},
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{btn_local},
		sub {
			$_[0]->btn_local;
		},
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{btn_remote},
		sub {
			$_[0]->btn_remote;
		},
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{btn_delete},
		sub {
			$_[0]->btn_delete;
		},
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{btn_ok},
		sub {
			$_[0]->btn_ok;
		},
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{btn_cancel},
		sub {
			$_[0]->btn_cancel;
		},
	);

	$self->Show(1);
	return $self;
}

1;

sub btn_login { 
	my $self     = shift;
	my $username = $self->{txt_login}->GetValue;
	my $password = $self->{txt_password}->GetValue;
	my $sync     = $self->current->ide->config_sync;

	# Handle login / logout logic toggle
	if ($sync->{state} eq 'logged_in') { 
		if ($sync->logout =~ /success/) { 
			Wx::MessageBox(
				sprintf( 'Successfully logged out.' ), 
				Wx::gettext('Error'),
				Wx::wxOK,
				$self,
			); 
			$self->{btn_login}->SetLabel('Log in'); 
		}
		else { 
			Wx::MessageBox(
				sprintf( 'Failed to log out.' ), 
				Wx::gettext('Error'),
				Wx::wxOK,
				$self,
			); 
		}

		$self->{lbl_status}->SetLabel( $sync->english_status );
		$self->{lbl_status_info}->SetLabel( $sync->english_status );
		return;
	}

	if (not $username or not $password) { 
		Wx::MessageBox(
			sprintf( Wx::gettext('Please input a valid value for both username and password') ),
			Wx::gettext('Error'),
			Wx::wxOK,
			$self,
		);
		return;
	}

	# attempt login
	my $rc = $sync->login(
		{ 
			username => $username,
			password => $password,
		}
	);

	$self->{lbl_status}->SetLabel( $sync->english_status );
	$self->{lbl_status_info}->SetLabel( $sync->english_status );

	if ($sync->{state} eq 'logged_in') { 
		$self->{btn_login}->SetLabel('Log out');
	}

	# print the return information
	Wx::MessageBox(
		sprintf( '%s', $rc ), 
		Wx::gettext('Error'),
		Wx::wxOK,
		$self,
	);  

}

sub btn_register { 
	my $self          = shift;
	my $sync          = $self->current->ide->config_sync;
	my $username      = $self->{txt_username}->GetValue;
	my $pw            = $self->{txt_pw}->GetValue;
	my $pw_confirm    = $self->{txt_pw_confirm}->GetValue;
	my $email         = $self->{txt_email}->GetValue;
	my $email_confirm = $self->{txt_email_confirm}->GetValue;

	# validation of inputs 
	if (not $username or
		not $pw or
		not $pw_confirm or
		not $email or 
		not $email_confirm) { 
		Wx::MessageBox(
			sprintf( Wx::gettext('Please ensure all inputs have appropriate values.') ), 
			Wx::gettext('Error'),
			Wx::wxOK,
			$self,
		);
		return;
	}

	# not sure if password quality rules should be enforced at this level?
	if ($pw ne $pw_confirm) { 
		Wx::MessageBox(
			sprintf( Wx::gettext('Password and confirmation do not match.') ), 
			Wx::gettext('Error'),
			Wx::wxOK,
			$self,
		);
		return;
	}

	if ($email ne $email_confirm) { 
		Wx::MessageBox(
			sprintf( Wx::gettext('Email and confirmation do not match.') ), 
			Wx::gettext('Error'),
			Wx::wxOK,
			$self,
		);
		return;
	}

	# attempt registration
	my $rc = $sync->register(
		{
			username => $username,
			password => $pw,
			email    => $email,
		}
	);

	# print the return information
	Wx::MessageBox(
		sprintf( '%s', $rc ),  
		Wx::gettext('Error'),
		Wx::wxOK,
		$self,
	);  
}

sub btn_local { 
	my $self = shift;
	my $sync = $self->current->ide->config_sync;
	my $rc   = $sync->local_to_server;

	Wx::MessageBox(
		sprintf( '%s', $rc ),
		Wx::gettext('Error'),
		Wx::wxOK,
		$self,
	);  
}

sub btn_remote { 
	my $self = shift;
	my $sync = $self->current->ide->config_sync;
	my $rc   = $sync->server_to_local;

	Wx::MessageBox(
		sprintf( '%s', $rc ),
		Wx::gettext('Error'),
		Wx::wxOK,
		$self,
	);  

}

sub btn_delete { 
	my $self = shift;
	my $sync = $self->current->ide->config_sync;
	my $rc   = $sync->server_delete;

	Wx::MessageBox(
		sprintf( '%s', $rc ),
		Wx::gettext('Error'),
		Wx::wxOK,
		$self,
	);  

}

# save changes to dialog inputs to config
sub btn_ok { 
	my $self   = shift;
	my $config = $self->current->config;

	# Save the server access defaults
	$config->set( config_sync_server   => $self->{txt_remote}->GetValue   );
	$config->set( config_sync_username => $self->{txt_login}->GetValue    );
	$config->set( config_sync_password => $self->{txt_password}->GetValue );

	$self->Destroy;
}

# discard all changes to config
sub btn_cancel { 
	$_[0]->Destroy;
}

=pod

=head1 COPYRIGHT & LICENSE

Copyright 2008-2010 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute it and/or modify it under the
same terms as Perl 5 itself.

=cut

# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
