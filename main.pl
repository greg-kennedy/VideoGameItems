#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

###############################################################################
# A Twitter bot to post a gallery, one pic at a time, every N hours
###############################################################################

use JSON::PP qw( decode_json );
use Twitter::API;
use File::Spec;
use Image::PNG::Libpng qw( read_png_file create_write_struct );

###############################################################################
# Globals
###############################################################################
my $total_weight = 0;

###############################################################################
# Helper functions
###############################################################################
sub read_json {
  my $path = shift;

  open my $fh, '<:raw', $path;
  local $/ = undef;
  my $content = <$fh>;
  close $fh;

  return decode_json $content;
};

sub readdir_recursive {
  my $path = shift;

  opendir(my $dh, $path);
  my @items = File::Spec->no_upwards( readdir($dh) );
  closedir $dh;

  my %ret;
  foreach my $entry (@items) {
    my $filename = $path . '/' . $entry;
    if ($entry eq 'index.json') {
      $ret{$filename} = read_json($filename);
      my $weight = sqrt(keys %{$ret{$filename}{items}});
      $ret{$filename}{weight} = $weight;
      $total_weight += $weight;
    }
    elsif (-d $filename) {
      %ret = ( %ret, readdir_recursive($filename) );
    } 
  }
  return %ret;
}

###############################################################################
# MAIN
###############################################################################
# Read the config file
my $config = read_json('config.json');

# Read all index.json files.
#  If command-line arguments are used, read only those instead.
my %data;
if (@ARGV) {
  foreach my $file (@ARGV) {
    $data{$file} = read_json($file);
    my $weight = sqrt(keys %{$data{$file}{items}});
    $data{$file}{weight} = $weight;
    $total_weight += $weight;
  }
} else {
  %data = readdir_recursive('data')
} 

# Choose a file to post.
# We begin by picking a game.
#  This uses sqrt of the number of entries in each,
#  so that games with a lot of items are more common
#  but don't crowd out smaller inventories

# choose a random number between 0 and total_weight
my $pick = rand($total_weight);

# go back through the list of keys, this time subtracting until we find our match
foreach my $file (keys %data) {
  $pick -= $data{$file}{weight};

  if ($pick <= 0) {
    # having picked our file we can now select one item to post
    my $item = (keys %{ $data{$file}{items} })[rand keys %{ $data{$file}{items} }];

    # Build a complete filename to use for the source image
    my ($volume, $directories, $json_name) =
                   File::Spec->splitpath( $file );
    my $upload_file = File::Spec->catpath($volume, $directories, $item);

    ####
    # need to upscale the image
    my $src_png = read_png_file($upload_file, transforms => Image::PNG::Libpng::PNG_TRANSFORM_EXPAND);
    my ($src_height, $src_width, $src_channels, $src_rows) =
      ($src_png->height(), $src_png->width(), $src_png->get_channels(), $src_png->get_rows());

    #print STDERR "Input file $item: $src_width x $src_height, $src_channels channels\n";

    my ($canvas_height, $canvas_width, $canvas_offs_x, $canvas_offs_y);
    # determine a 2:1 canvas that can contain the source image
    if ($src_height * 2 > $src_width) {
      # Image is taller than 2:1
      $canvas_width = $src_height * 2;
      $canvas_height = $src_height;
      $canvas_offs_x = int( ($canvas_width - $src_width) / 2 );
      $canvas_offs_y = 0;
    } else {
      # Image is wider than 2:1
      $canvas_width = $src_width;
      $canvas_height = int($src_width / 2);
      $canvas_offs_x = 0;
      $canvas_offs_y = int( ($canvas_height - $src_height) / 2 );
    }

    # upscale
    my $scale = int(4096 / $canvas_width);

    my $dest_png = create_write_struct();
    $dest_png->set_IHDR({height => $scale * $canvas_height, width => $scale * $canvas_width, bit_depth => 8,
                 color_type => Image::PNG::Libpng::PNG_COLOR_TYPE_RGBA});

#    $dest_png->set_compression_level(9);

    # begin writing the output rows by copying from the input
    my @dest_rows;
    for my $y (0 .. $canvas_height - 1) {
      if ($y < $canvas_offs_y || $y >= $canvas_offs_y + $src_height) {
        for (my $q = 0; $q < $scale; $q ++) {
          $dest_rows[$q + $scale * $y] = '\0' x ($canvas_width * $scale * 4);
        }
      } else {
        for my $x (0 .. $canvas_width - 1) {
          if ($x < $canvas_offs_x || $x >= $canvas_offs_x + $src_width) {
            for (my $q = 0; $q < $scale; $q ++) {
              $dest_rows[$q + $scale * $y] .= pack 'N*', ((0) x $scale);
            }
          } else {
            my $pixel;
            if ($src_channels == 4) {
              $pixel = substr($src_rows->[$y - $canvas_offs_y], ($x - $canvas_offs_x) * 4, 4);
            } else {
              $pixel = substr($src_rows->[$y - $canvas_offs_y], ($x - $canvas_offs_x) * 3, 3) . chr(255);
            }
            for (my $q = 0; $q < $scale; $q ++) {
              $dest_rows[$q + $scale * $y] .= ($pixel) x $scale;
            }
          }
        }
      }
    }
    $dest_png->set_rows(\@dest_rows);
    my $img = $dest_png->write_to_scalar();

    # Connect to Twitter
    my $client = Twitter::API->new_with_traits(
      traits          => [ qw( NormalizeBooleans DecodeHtmlEntities RetryOnError ) ],
      consumer_key    => $config->{consumer_key},
      consumer_secret => $config->{consumer_secret},
      access_token    => $config->{access_token},
      access_token_secret => $config->{access_token_secret},
    );

    ###
    # READY TO POST!!
    # Upload media image
    my $upload_return_object = $client->post('https://upload.twitter.com/1.1/media/upload.json', {
      media_category => 'tweet_image',
      media => [ undef, $item, Content_Type => "image/png", Content => $img ]
    });

    # Compose tweet.
    my $post = sprintf("Game: %s\nSystem: %s\nDeveloper: %s\nItem Name: %s",
      $data{$file}{name}, $data{$file}{system}, $data{$file}{creator}, $data{$file}{items}{$item}{name});

    # post
    my $r = $client->post('statuses/update', {
        status    => $post,
        media_ids => $upload_return_object->{media_id},
    });
    my $last_id = $r->{id_str};

    # Add a description, if present
    if ($data{$file}{items}{$item}{description}) {
      # followup with details
      $r = $client->post('statuses/update', {
          status                       => $data{$file}{items}{$item}{description},
          in_reply_to_status_id        => $last_id,
          auto_populate_reply_metadata => 'true'
      });
    }

    last;
  }
}

