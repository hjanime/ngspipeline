# importing from mother script:
## for every sample
#     $pipeline : CO::NGSPipeline object
#     $r1       : pair 1, array reference
#     $r2       : pair 2, array reference
#     $prefix1  : prefix for pair 1 to output
#     $prefix2  : prefix for pari 2 to output
#     $library  : library class for lanes of the sample

my $qid = {};
$qid->{alignment} = [];
my $sam_sort_list = [];
for(my $i = 0; $i < scalar(@$r1); $i ++) {
	my $r1_fastq = $r1->[$i];
	my $r2_fastq = $r2->[$i];
	
	
	###################################################################
	# fastqc
	###################################################################
	$pipeline->set_job_name("$sample_id"."_bsmap_fastqc_r1_$i");
	$qid->{fastqc_r1} = $pipeline->bsmap->fastqc(
		fastq      => $r1_fastq,
		output_dir => "$pipeline->{dir}/fastqc_r1_$i"
	);

	$pipeline->set_job_name("$sample_id"."_bsmap_fastqc_r2_$i");
	$qid->{fastqc_r2} = $pipeline->bsmap->fastqc(
		fastq      => $r2_fastq,
		output_dir => "$pipeline->{dir}/fastqc_r2_$i"
	);
			
	####################################################################
	# trim
	####################################################################
	$pipeline->set_job_name("$sample_id"."_bsmap_trimmed_$i");
	$qid->{trim} = $pipeline->bsmap->trim(
		fastq1  => $r1_fastq,
		fastq2  => $r2_fastq,
		output1 => "$prefix1.trimmed.$i.fastq.gz",
		output2 => "$prefix2.trimmed.$i.fastq.gz",
	);
			
	###################################################################
	# fastqc after trimming
	###################################################################
	$pipeline->set_job_name("$sample_id"."_bsmap_fastqc_r1_trimmed_$i");
	$pipeline->set_job_dependency($qid->{trim});
	$qid->{fastqc_r1_trimmed} = $pipeline->bsmap->fastqc
		fastq      => "$prefix1.trimmed.$i.fastq.gz",
		output_dir => "$pipeline->{dir}/fastqc_r1_trimmed_$i"
	);

	$pipeline->set_job_name("$sample_id"."_bsmap_fastqc_r2_trimmed_$i");
	$pipeline->set_job_dependency($qid->{trim});
	$qid->{fastqc_r2_trimmed} = $pipeline->bsmap->fastqc(
		fastq      => "$prefix2.trimmed.$i.fastq.gz",
		output_dir => "$pipeline->{dir}/fastqc_r2_trimmed_$i"
	);
											 
	###################################################################
	# alignment
	###################################################################
	$pipeline->set_job_name("$sample_id"."_bsmap_alignment_$i");
	$pipeline->set_job_dependency($qid->{trim});
	$qid->{alignment}->[$i] = $pipeline->bsmap->align(
		fastq1       => "$prefix1.trimmed.$i.fastq.gz",
	    fastq2       => "$prefix2.trimmed.$i.fastq.gz",
		output       => "$prefix1.$i.sorted.bam",
		delete_input => 1,
	);
			
	####################################################################
	# flagstat
	####################################################################
	$pipeline->set_job_name("$sample_id"."_bsmap_flagstat_$i");
	$pipeline->set_job_dependency($qid->{alignment}->[$i]);
	$qid->{flagstat} = $pipeline->bsmap->samtools_flagstat(
		sam          => "$prefix1.$i.sorted.bam",
		output       => "$prefix1.$i.flagstat",
		delete_input => 0
	);

	$sam_sort_list->[$i] = "$prefix1.$i.sorted.bam";
}
		
########################################################################
# merge, nodup
########################################################################
$pipeline->set_job_name("$sample_id"."_bsmap_merge_and_nodup");
$pipeline->set_job_dependency(@{$qid->{alignment}});
$qid->{remove_duplicate} = $pipeline->bsmap->merge_nodup(
	sam_list     => $sam_sort_list,
	output       => "$prefix1.nodup.bam",
	library      => $library,
	delete_input => 1
);
                                   
########################################################################
# insert size
########################################################################
$pipeline->set_job_name("$sample_id"."_bsmap_insertsize");
$pipeline->set_job_dependency($qid->{remove_duplicate});
$qid->{insertsize} = $pipeline->bsmap->picard_insertsize(
	sam => "$prefix1.nodup.bam"
);

########################################################################
# lambda conversion
########################################################################
$pipeline->set_job_name("$sample_id"."_bsmap_lambda_conversion");
$pipeline->set_job_dependency($qid->{remove_duplicate});
$qid->{lambda_conversion} = $pipeline->bsmap->lambda_conversion(
	bam    => "$prefix1.nodup.bam",
	output => "$prefix1.lambda.conversion.txt"
);
			
########################################################################
# call methylation, default methylation calling by BSMAP
########################################################################
if($no_bissnp) {
	$pipeline->set_job_name("$sample_id"."_bsmap_methylation_calling");
	$pipeline->set_job_dependency($qid->{remove_duplicate});
	$qid->{methy_calling} = $pipeline->bsmap->call_methylation(
		sam    => "$prefix1.nodup.bam",
		output => "$prefix1.methylcall.txt"
	);
} else {
########################################################################
# bissnp methylation calling
########################################################################
	$pipeline->set_job_name("$sample_id"."_bissnp_methylation_calling");
	$pipeline->set_job_dependency($qid->{remove_duplicate});
	$qid->{methy_calling} = $pipeline->bissnp->call_methylation(
		bam => "$prefix1.nodup.bam",
	);
											
	$pipeline->set_job_name("$sample_id"."_bsmap_QC");
	$pipeline->set_job_dependency($qid->{methy_calling});
	$qid->{qc} = $pipeline->bsmap->bsqc(
		dir    => $pipeline->{dir},
		tool   => "bsmap",
		sample => "$sample_id",
		base_dir => $SCRIPT_DIR,
	);
	
	for my $chr (map {"chr$_"} (1..22, "X", "Y")) {
		$pipeline->set_job_name("$sample_id"."_bsseq_RData_$chr");
		$pipeline->set_job_dependency($qid->{methy_calling});
		$qid->{RData} = $pipeline->bsmap->RData(
			bedgraph   => "$prefix1.nodup.cpg.filtered.CG.bedgraph",
			sample_id  => $sample_id,
			chr        => $chr,
		);
	}
}

1;
