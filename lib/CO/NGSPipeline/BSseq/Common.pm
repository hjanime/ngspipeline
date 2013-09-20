package CO::NGSPipeline::BSseq::Common;


use strict;
use CO::NGSPipeline::BSseq::Config;
use CO::NGSPipeline::Config;
use CO::NGSPipeline::Utils;
use File::Basename;

sub bsqc {
	my $self = shift;
	
	my %param = ( "dir" => undef,
	              "tool" => undef,
	              "sample" => undef,
	              "base_dir" => undef,
				  @_);
	
	my $sample_dir    = to_abs_path( $param{dir} );
	my $tool = $param{tool};
	my $sample = $param{sample};
	my $base_dir = to_abs_path( $param{base_dir});
	
	my $pipeline = $self->{pipeline};
	
	$pipeline->add_command("perl $base_dir/utils/report/bs_report.pl --tool $tool --dir $sample_dir --sample $sample");

	my $qid = $pipeline->run("-N" => $pipeline->get_job_name ? $pipeline->get_job_name : "_common_bsqc",
							 "-l" => { nodes => "1:ppn=1:lsdf", 
									    mem => "20GB",
										walltime => "10:00:00"});
	return($qid);

}



sub RData {
	my $self = shift;
	
	my %param = ( "bedgraph" => undef,
		          "sample_id" => undef,
		          "chr" = undef,
				  @_);

	my $bedgraph = to_abs_path($param{bedgraph});
	my $sampleName = $param{sample_id};
	my $chr = $param{'chr'};
	my $output_dir = to_abs_path($param{output_dir});
	
	my $pipeline = $self->{pipeline};
	
	# extract information belongs to $chr into a temporary file
	my $bedgraph_chr = "$pipeline->{tmp_dir}/".basename($bedgraph).".$chr";
	$pipeline->add_command("grep -e \"^$chr\\s\" $bedgraph > $bedgraph_chr", 0);
	
	my $file_str = "c(\"$bedgraph_chr\")";
	my $sampleName_str = "c(\"$sampleName\")";
	
	my $R = <<RCODE;
	
library(bsseq)
d = read.table($file_str, sep = "\t", stringsAsFactors = FALSE, skip = 1)
chr = d[[1]]
M = cbind(round(d[[4]]/100*d[[5]]))
Cov = cbind(d[[5]])
bsseq_$chr = BSseq(chr = chr, pos = d[[2]], M = M, Cov = Cov, sampleNames = $sampleName_str)

dir.create("$pipeline->{dir}/bsseq_RData", showWarnings = FALSE)
save(bsseq_$chr, file = "$pipeline->{dir}/bsseq_RData/$sampleName.bsseq_$chr.RData")

RCODE

	my ($tmp_fh, $tmp_file) = tempfile(DIR => $pipeline->{tmp_dir}, SUFFIX => '.R');
	
	$tmp_file = to_abs_path($tmp_file);
	
	print $tmp_fh $R;
	close $tmp_fh;
	
	$pipeline->add_command("Rscript $tmp_file");
	$pipeline->del_file($bedgraph_chr);
	$pipeline->del_file($tmp_file);
	
	my $qid = $pipeline->run("-N" => $pipeline->get_job_name ? $pipeline->get_job_name : "_save_bsseq_RData",
							 "-l" => { nodes => "1:ppn=1:lsdf", 
									    mem => "30GB",
										walltime => "10:00:00"});

}


1;
