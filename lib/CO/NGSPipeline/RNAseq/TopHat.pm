package CO::NGSPipeline::RNAseq::TopHat;

use strict;
use CO::NGSPipeline::RNAseq::Config;
use CO::NGSPipeline::Utils;

use base qw(CO::NGSPipeline::RNAseq::Common
            CO::NGSPipeline::Common);

sub new {
	my $class = shift;
	$class = ref($class) ? ref($class) : $class;
	
	my $pipeline = shift;
	
	my $self = {"pipeline" => $pipeline};
	
	return bless $self, $class;
}

sub align {
	my $self = shift;
	
	my %param = ( "fastq1" => undef,
	              "fastq2" => undef,
				  "output" => undef,
				  "sample_id" => "sample",
				  "delete_input" => 0,
				  "strand" => 0,
				  @_);
	
	my $fastq1 = to_abs_path($param{fastq1});
	my $fastq2 = to_abs_path($param{fastq2});
	my $output = to_abs_path($param{output});
	my $delete_input = $param{delete_input};
	my $sample_id = $param{sample_id};
	my $strand = $param{strand};
	
	my $pipeline = $self->{pipeline};
	
	if($strand) {
		$pipeline->add_command("tophat2 -o $pipeline->{dir} -p 8 --library-type fr-unstranded -r 200 --mate-std-dev 50 --b2-sensitive -g 1 --no-coverage-search --GTF $GENCODE_GTF --transcriptome-index=$GENCODE_BOWTIE2_INDEX $BOWTIE2_INDEX $fastq1 $fastq2");
	} else {
		$pipeline->add_command("tophat2 -o $pipeline->{dir} -p 8 --library-type fr-firststrand -r 200 --mate-std-dev 50 --b2-sensitive -g 1 --no-coverage-search --GTF $GENCODE_GTF --transcriptome-index=$GENCODE_BOWTIE2_INDEX $BOWTIE2_INDEX $fastq1 $fastq2");
	}
	$pipeline->add_command("mv $pipeline->{dir}/accepted_hits.bam $output", 0);
	$pipeline->check_filesize("$output");
	my $qid = $pipeline->run("-N" => $pipeline->get_job_name ? $pipeline->get_job_name : "_tophat2_align",
							 "-l" => { nodes => "1:ppn=8:lsdf", 
									    mem => "10GB",
										walltime => "150:00:00"});

	return($qid);

}

1;
