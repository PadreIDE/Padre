package Padre::Util::Win32;

=pod

=head1 NAME

Padre::Util::Win32 - Padre Win32 API Functions

=head1 DESCRIPTION

The C<Padre::Util::Win32> package provides an XS wrapper for Win32
API functions

All functions are exportable and documented for maintenance purposes,
but except for in the L<Padre> core distribution you are discouraged in the
strongest possible terms from using these functions, as they may be
moved, removed or changed at any time without notice.

=head1 FUNCTIONS

=cut

use 5.008;
use strict;
use warnings;
use Padre::Constant ();

our $VERSION = '0.94';

# This module may be loaded by others, so don't crash on Linux when just being loaded:
if (Padre::Constant::WIN32) {
	require Win32;
	require XSLoader;
	XSLoader::load( 'Padre::Util::Win32', $VERSION );
} else {
	require Padre::Logger;
	Padre::Logger::TRACE("WARN: Inefficiently loading Padre::Util::Win32 when not on Win32");
}

=head2 C<GetLongPathName>

  Padre::Util::Win32::GetLongPathName($path);

Converts the specified path C<$path> to its long form.
Returns C<undef> for failure, or the long form of the specified path

=cut

# Is this still needed?
sub GetLongPathName {
	die "Win32 function called!" unless Padre::Constant::WIN32;
	my $path = shift;
	return Win32::GetLongPathName($path);
}

=head2 C<Recycle>

  Padre::Util::Win32::Recycle($file_to_recycle);

Move C<$file_to_recycle> to recycle bin
Returns C<undef> (failed), zero (aborted) or one (success)

=cut

sub Recycle {
	die "Win32 function called!" unless Padre::Constant::WIN32;
	my $file_to_recycle = shift;
	return _recycle_file($file_to_recycle);
}

=head2 C<AllowSetForegroundWindow>

  Padre::Util::Win32::AllowSetForegroundWindow($pid);

Enables the specified process C<$pid> to set the foreground window
via C<SetForegroundWindow>

L<http://msdn.microsoft.com/en-us/library/ms633539(VS.85).aspx>

=cut

#
# Enables the specified process to set the foreground window
# via SetForegroundWindow
#
sub AllowSetForegroundWindow {
	die "Win32 function called!" unless Padre::Constant::WIN32;
	my $pid = shift;
	return _allow_set_foreground_window($pid);
}

=head2 C<ExecuteProcessAndWait>

  Padre::Util::Win32::ExecuteProcessAndWait(
      directory  => $directory,
      file       => $file,
      parameters => $parameters,
      show       => $show,
  )

Execute a background process named "C<$file> C<$parameters>" with the current
directory set to C<$directory> and wait for it to end. If you set C<$show> to 0,
then you have an invisible command line window on win32!

=cut

sub ExecuteProcessAndWait {
	die "Win32 function called!" unless Padre::Constant::WIN32;
	my %params     = @_;
	my $directory  = $params{directory} || '.';
	my $show       = ( $params{show} ) ? 1 : 0;
	my $parameters = $params{parameters} || '';

	return _execute_process_and_wait( $params{file}, $parameters, $directory, $show );
}

=head2 C<GetCurrentProcessMemorySize>

  Padre::Util::Win32::GetCurrentProcessMemorySize;

Returns the current process memory size in bytes

=cut

sub GetCurrentProcessMemorySize {
	die "Win32 function called!" unless Padre::Constant::WIN32;
	return _get_current_process_memory_size();
}

=head2 C<GetLastErrorString>

  Padre::Util::Win32::GetLastError;

Returns the error code of the last Win32 API call.

The list of error codes could be found at
L<http://msdn.microsoft.com/en-us/library/ms681381(VS.85).aspx>.

=cut

sub GetLastError {
	die "Win32 function called!" unless Padre::Constant::WIN32;
	return Win32::GetLastError();
}

=head2 C<GetLastErrorString>

  Padre::Util::Win32::GetLastErrorString;

Returns the string representation for the error code of the last
Win32 API call.

=cut

sub GetLastErrorString {
	die "Win32 function called!" unless Padre::Constant::WIN32;
	return Win32::FormatMessage( Win32::GetLastError() );
}


1;

__END__

=pod

=head1 COPYRIGHT

Copyright 2008-2012 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

