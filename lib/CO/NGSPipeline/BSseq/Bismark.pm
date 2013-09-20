package CO::NGSPipeline::BSseq::Bismark;

use strict;
use CO::NGSPipeline::BSseq::Config;
use CO::NGSPipeline::Utils;
use File::Basename;

use base qw(CO::NGSPipeline::BSseq::Common
            CO::NGSPipeline::Common);


sub new {
	my $class = shift;
	$class = ref($class) ? ref($class) : $class;
	
	my $pipeline = shift;
	
	my $self = {"pipeline" => $pipeline};
	
	return bless $self, $class;
}

=item C<$self-E<gt>align(HASH)>

Bismark alignment

  fastq1        path of read 1
  fastq2        path of read 2
  output        path of output
  output_dir    dir for the trimmed data
  delete_input  whether delete input files
 
=cut
sub align {
	my $self = shift;
	my $pipeline = $self->{pipeline};
	
	my %param = ( "fastq1" => undef,
	              "fastq2" => undef,
				  "output" => undef,
				  "output_dir" => $pipeline->{dir},
				  "delete_input" => 0,
				  @_);
	
	my $fastq1     = to_abs_path( $param{fastq1} );
	my $fastq2     = to_abs_path( $param{fastq2} );
	my $output     = to_abs_path( $param{output} );
	my $output_dir = to_abs_path( $param{output_dir} );
	my $delete_input = $param{delete_input};
	
	$output = $output_dir."/".basename($output);
	
	my $bam_option = $output =~/\.bam$/ ? "--bam" : "";
	my $ext = $output =~/\.bam$/ ? "bam" : "sam";
	
	$pipeline->add_command("perl $BISMARK_BIN_DIR/bismark --bowtie2 -N 1 --score_min L,0,-0.6 -p 8 --fastq $bam_option --chunkmb 1024 -o $output_dir --temp_dir $pipeline->{tmp_dir} $BISMARK_GENOME_DIR -1 $fastq1 -2 $fastq2");
	$pipeline->add_command("mv $fastq1"."_bismark_bt2_pe.$ext $output", 0);
	$pipeline->add_command("mv $fastq1"."_bismark_bt2_PE_report.txt $pipeline->{report_dir}", 0);
	$pipeline->add_command("mv $fastq1"."_bismark_PE.alignment_overview.png $pipeline->{report_dir}", 0);
	$pipeline->del_file($fastq1, $fastq2) if($delete_input);
	$pipeline->check_filesize($output); # 1M
	my $qid = $pipeline->run("-N" => $pipeline->get_job_name ? $pipeline->get_job_name : "_bismark_align",
							 "-l" => { nodes => "1:ppn=16:lsdf", 
									    mem => "15GB",
										walltime => "150:00:00"});

	return($qid);
}

sub lambda_conversion {
	my $self = shift;
	
	my %param = ( "bam" => undef,
	               "output" => undef,
	               "delete_input" => 0,
				   @_);
	
	my $bam    = to_abs_path($param{bam});
	my $output = to_abs_path($param{output});
	my $delete_input = $param{delete_input};
	
	my $pipeline = $self->{pipeline};
	
	$pipeline->add_command("samtools view -h $bam lambda > $pipeline->{tmp_dir}/lambda.sam");
	$pipeline->add_command("JAVA_OPTIONS=-Xmx4G picard.sh SortSam INPUT=$pipeline->{tmp_dir}/lambda.sam OUTPUT=$pipeline->{tmp_dir}/lambda.sort_queryname.sam SORT_ORDER=queryname TMP_DIR=$pipeline->{tmp_dir} VALIDATION_STRINGENCY=SILENT");
	$pipeline->add_command("perl $BISMARK_BIN_DIR/bismark_methylation_extractor -p -o $pipeline->{tmp_dir}/ --no_overlap --comprehensive --merge_non_CpG --bedGraph --counts --CX $pipeline->{tmp_dir}/lambda.sort_queryname.sam");
	$pipeline->add_command("cat $pipeline->{tmp_dir}/lambda.sort_queryname.bedGraph | awk '{a+=\$4/100}END{print 1-a/NR}' > $output.report.txt", 0);
	$pipeline->add_command("mv $pipeline->{tmp_dir}/lambda.sort_queryname.bedGraph $output", 0);
	
	$pipeline->del_file("$pipeline->{tmp_dir}/lambda.sam");
	$pipeline->del_file("$pipeline->{tmp_dir}/lambda.sort_queryname.sam");

	my $qid = $pipeline->run("-N" => $pipeline->get_job_name ? $pipeline->get_job_name : "_bsmap_lambda_conversion",
							 "-l" => { nodes => "1:ppn=1:lsdf", 
									    mem => "4GB",
										walltime => "5:00:00"});

	return($qid);

}

=item C<$self-E<gt>call_methylation(HASH)>

Bismark methylation calling

  sam           sam files
  output_dir    dir for the trimmed data
  delete_input  whether delete input files
 
=cut
sub call_methylation {
	my $self = shift;
	
	my $pipeline = $self->{pipeline};
	
	my %param = ( "sam" => undef,
	               "output_dir" => $pipeline->{dir},
	               "delete_input" => 0,
				   @_);
	
	my $sam        = to_abs_path($param{sam});
	my $bedgraph   = $sam;
	$bedgraph =~s/\.(sam|bam)$/.bedGraph/;
	$bedgraph = basename($bedgraph);
	my $output_dir = to_abs_path($param{output_dir});
	my $delete_input = $param{delete_input};
	
	
	$pipeline->add_command("perl $BISMARK_BIN_DIR/bismark_methylation_extractor -p -o $output_dir --no_overlap --report --comprehensive --merge_non_CpG --bedGraph --counts $sam");
	$pipeline->del_file($sam) if($delete_input);
	my $qid = $pipeline->run("-N" => $pipeline->get_job_name ? $pipeline->get_job_name : "_bismark_call_methylation",
							 "-l" => { nodes => "1:ppn=1:lsdf", 
									    mem => "5GB",
										walltime => "50:00:00"});

	return($qid);
}

1;
