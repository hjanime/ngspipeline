#!/bin/perl/bin/

BEGIN {
	use File::Basename;
	unshift(@INC, dirname($0)."/lib");
}

use strict;
use CO::PipelineMaker;
use File::Basename;
use CO::NGSPipeline::Getopt;

use CO::NGSPipeline::Pipeline::GSNAP;
use CO::NGSPipeline::Pipeline::TopHat;
use CO::NGSPipeline::Pipeline::STAR;
use CO::NGSPipeline::Pipeline::deFuse;
use CO::NGSPipeline::Pipeline::FusionMap;
use CO::NGSPipeline::Pipeline::FusionHunter;
use CO::NGSPipeline::Pipeline::TopHatFusion;

my $opt = CO::NGSPipeline::Getopt->new;

$opt->before("

USAGE:

  perl $0 --list file --dir dir --tool tool
  perl $0 --list file --dir dir --tool tool --strand
  perl $0 --list file --dir dir --tool tool --enforce
  perl $0 --list file --dir dir --tool tool --sample s1,s2
  
");

$opt->after("
NOTE:
  If your fastq files are stored in the standard directory structure which
are generated by data management group, use get_sample_list_from_std_dir.pl
first to generate sample list file.

");

my $wd = "analysis";
my $tool = "bsmap";
my $list;
my $std_dir;
my $enforce = 0;
my $request_sampleid;
my $is_strand_specific = 0;
my $do_test = 0;
my $filesize = 1024*1024;

$opt->add(\$list, "list=s");
$opt->add(\$wd, "dir=s");
$opt->add(\$tool, "tool=s", "available tools: tophat, star, gsnap, defuse, fusionmap, fusionhunter");
$opt->add(\$enforce, "enforce");
$opt->add(\$request_sampleid, "sample=s");
$opt->add(\$do_test, "test");
$opt->add(\$filesize, "filesize=i");
$opt->add(\$is_strand_specific, "strand", "strand specific");

$opt->getopt;

my $sample = $list;

foreach my $sample_id (sort keys %$sample) {
	
	my $r1 = $sample->{$sample_id}->{r1};
	my $r2 = $sample->{$sample_id}->{r2};
	
	if(scalar(@$r1) > 1) {
		die "Currently only support RNA seq data one lane per sample. $sample_id has multiple lanes.\n";
	}
}

foreach my $sample_id (sort keys %$sample) {
	
	print "=============================================\n";
	print "submit pipeline for $sample_id\n";
	
	my $r1 = $sample->{$sample_id}->{r1};
	my $r2 = $sample->{$sample_id}->{r2};
	my $library = $sample->{$sample_id}->{library};

	my $pm = CO::PipelineMaker->new(dir => "$wd/$sample_id",
	                                enforce => $enforce,
									do_test => $do_test,
									filesize => $filesize);

	# prefix means absolute path without fast/fq or fast.gz/fq.gz
	our $prefix1 = basename($r1->[0]);
	$prefix1 =~s/\.(fq|fastq)(\.gz)?$//;
	$prefix1 = "$pm->{dir}/$prefix1";
	our $prefix2 = basename($r2->[0]);
	$prefix2 =~s/\.(fq|fastq)(\.gz)?$//;
	$prefix2 = "$pm->{dir}/$prefix2";
	
	
	my $pipeline;
	if($tool eq "gsnap") {
	
		$pipeline = CO::NGSPipeline::Pipeline::GSNAP->new();
		
	} elsif($tool eq "tophat") {
	
		$pipeline = CO::NGSPipeline::Pipeline::TopHat->new();
		
	}  elsif($tool eq "star") {
	
		$pipeline = CO::NGSPipeline::Pipeline::STAR->new();
		
	} elsif($tool eq "defuse") {
	
		$pipeline = CO::NGSPipeline::Pipeline::deFuse->new();
		
	} elsif($tool eq "fusionmap") {
	
		$pipeline = CO::NGSPipeline::Pipeline::FusionMap->new();
		
	} elsif($tool eq "fusionhunter") {
	
		$pipeline = CO::NGSPipeline::Pipeline::FusionHunter->new();
		
	} elsif($tool eq "tophatfusion") {
	
		$pipeline = CO::NGSPipeline::Pipeline::TopHatFusion->new();
		
	} else {
		die "--tool can only be set to one of 'gsnap', 'tophat', 'star', 'defuse', 'fusionmap' and 'fusionhunter'.\n";
	}
	
	$pipeline->set_pipeline_maker($pm);
	$pipeline->run(sample_id => $sample_id,
		               r1 => $r1,
					   r2 => $r2,
					   library => $library,
					   is_strand_specific =>$is_strand_specific,
					   );
					   
}

