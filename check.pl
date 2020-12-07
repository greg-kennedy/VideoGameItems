#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

###############################################################################
# Repository check tool
###############################################################################

use JSON::PP qw( decode_json );
use File::Spec;

###############################################################################
# Globals
###############################################################################
my $issues = 0;

###############################################################################
# Helper functions
###############################################################################
sub raise_issue {
  my $message = shift;

  warn $message;
  $issues ++;
}

sub read_json {
  my $path = shift;

  open my $fh, '<:raw', $path;
  local $/ = undef;
  my $content = <$fh>;
  close $fh;

  return decode_json $content;
};

sub check_recursive {
  my $path = shift;

  opendir(my $dh, $path);
  my @entries = File::Spec->no_upwards( readdir($dh) );
  closedir $dh;

  my $index;
  my @files;
  foreach my $entry (@entries) {
    if (-d File::Spec->catdir($path, $entry)) {
      check_recursive( File::Spec->catdir($path, $entry) );
    }

    elsif ($entry eq 'index.json') {
      $index = read_json( File::Spec->catfile($path, $entry) );
    }

    else {
      push @files, $entry;
    }
  }

  # if no index file, there should be no other files either
  if (! $index) {
    if (@files) {
      raise_issue("Extraneous files found in $path:\n" . join("\n", @files));
    }
  } else {
    # Check the index file for correctness
    foreach my $key ('name', 'creator', 'system') {
      raise_issue("$path: index.json missing '$key' field") unless delete $index->{$key};
    }

    # verify all files are accounted for
    foreach my $file (@files)
    {
      # validate filenames
      raise_issue("$path: $file is an invalid filename") unless $file =~ m/^[\w\-.]+$/;
      # test for case-insensitive collisions
      foreach my $file2 (@files)
      {
        raise_issue("$path: name collision between $file and $file2") if $file ne $file2 && lc($file) eq lc($file2);
      }

      # retrieve the key from the hash
      my $item = delete $index->{items}{$file};
      if (! $item)
      {
        raise_issue("$path: $file is not listed in index.json")
      } else {
        raise_issue("$path: $file in index.json is missing 'name' field") unless delete $item->{name};
        # optional keys
        delete $item->{description};
        # item should now be empty
        raise_issue("$path: extraneous keys (" . join(',', keys %{$item}) . ") in index.json for $file") if %{$item};
      }
    }
    # remove the items array, it should be empty now
    my $items = delete $index->{items};
    raise_issue("$path: listed but missing files (" . join(',', keys %{$items}) . ") in index.json") if %{$items};

    # json should be empty now
    raise_issue("$path: extraneous keys (" . join(',', keys %{$index}) . ") in index.json") if %{$index};
  }
}

###############################################################################
# MAIN
###############################################################################

check_recursive('data');

exit $issues;
