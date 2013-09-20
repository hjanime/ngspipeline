# importing from mother script:
## for every sample
#     $pipeline : CO::NGSPipeline object
#     $r1       : pair 1, array reference
#     $r2       : pair 2, array reference
#     $prefix1  : prefix for pair 1 to output
#     $prefix2  : prefix for pari 2 to output
#     $library  : library class for lanes of the sample

my $qid = {};
$qid->{sort_sam} = [];
my $sam_sort_list = [];
for(my $i = 0; $i < scalar(@$r1); $i ++) {
	my $r1_fastq = $r1->[$i];
	my $r2_fastq = $r2->[$i];
		
	###################################################################
	# fastqc
	###################################################################
	$pipeline->set_job_name("$sample_id"."_methylctools_fastqc_r1_$i");
	$qid->{fastqc_r1} = $pipeline->methylctools->fastqc(
		fastq      => $r1_fastq,
		output_dir => "$pipeline->{dir}/fastqc_r1_$i"
	);

	$pipeline->set_job_name("$sample_id"."_methylctools_fastqc_r2_$i");
	$qid->{fastqc_r2} = $pipeline->methylctools->fastqc(
		fastq      => $r2_fastq,
		output_dir => "$pipeline->{dir}/fastqc_r2_$i"
	);

	####################################################################
	# trim
	####################################################################
	$pipeline->set_job_name("$sample_id"."_methylctools_trimmed_$i");
	$qid->{trim} = $pipeline->methylctools->trim(
		fastq1  => $r1_fastq,
		fastq2  => $r2_fastq,
		output1 => "$prefix1.trimmed.$i.fastq.gz",
		output2 => "$prefix2.trimmed.$i.fastq.gz",
	);	
			
	###################################################################
	# fastqc after trimming
	###################################################################
	$pipeline->set_job_name("$sample_id"."_methylctools_fastqc_r1_trimmed_$i");
	$pipeline->set_job_dependency($qid->{trim});
	$qid->{fastqc_r1_trimmed} = $pipeline->methylctools->fastqc(
		fastq        => "$prefix1.trimmed.$i.fastq.gz",
		output_dir   => "$pipeline->{dir}/fastqc_r1_trimmed_$i",
		delete_input => 0
	);

	$pipeline->set_job_name("$sample_id"."_methylctools_fastqc_r2_trimmed_$i");
	$pipeline->set_job_dependency($qid->{trim});
	$qid->{fastqc_r2_trimmed} = $pipeline->methylctools->fastqc(
		fastq => "$prefix2.trimmed.$i.fastq.gz",
		output_dir => "$pipeline->{dir}/fastqc_r2_trimmed_$i",
		delete_input => 0
	);
											 
	####################################################################
	# fqconv
	####################################################################
	$pipeline->set_job_name("$sample_id"."_methylctools_fqconv_ct_$i");
	$pipeline->set_job_dependency($qid->{trim});
	$qid->{fqconv_ct} = $pipeline->methylctools->fqconv(
		fastq        => "$prefix1.trimmed.$i.fastq.gz",
		output       => "$prefix1.trimmed.conv.$i.fastq.gz",
		which_pair   => 1,
		delete_input => 1
	);
			
	$pipeline->set_job_name("$sample_id"."_methylctools_fqconv_ga_$i");
	$pipeline->set_job_dependency($qid->{trim});
	$qid->{fqconv_ga} = $pipeline->methylctools->fqconv(
		fastq        => "$prefix2.trimmed.$i.fastq.gz",
	    output       => "$prefix2.trimmed.conv.$i.fastq.gz",
		which_pair   => 2,
		delete_input => 1
	);
	
	####################################################################
	# align
	####################################################################
	my $use_convey = rand(1) > 0.8 ? 1 : 0;
	$pipeline->set_job_name("$sample_id"."_methylctools_alignment_ct_$i");
	$pipeline->set_job_dependency($qid->{fqconv_ct});
	$qid->{alignment_ct} = $pipeline->methylctools->bwa_aln(
		fastq        => "$prefix1.trimmed.conv.$i.fastq.gz",
		genome       => "$METHYLCTOOLS_GENOME_DIR/$METHYLCTOOLS_REF_GENOME_CONV",
		output       => "$prefix1.conv.$i.sai",
		delete_input => 0,
		use_convey   => $use_convey
	);
	
	$pipeline->set_job_name("$sample_id"."_methylctools_alignment_ga_$i");
	$pipeline->set_job_dependency($qid->{fqconv_ga});
	$qid->{alignment_ga} = $pipeline->methylctools->bwa_aln(
		fastq        => "$prefix2.trimmed.conv.$i.fastq.gz",
		genome       => "$METHYLCTOOLS_GENOME_DIR/$METHYLCTOOLS_REF_GENOME_CONV",
		output       => "$prefix2.conv.$i.sai",
		delete_input => 0,
		use_convey   => $use_convey
	);
			
	$pipeline->set_job_name("$sample_id"."_methylctools_sampe_$i");
	$pipeline->set_job_dependency($qid->{alignment_ct}, $qid->{alignment_ga});
	$qid->{sampe} = $pipeline->methylctools->sampe(
		aln1         => "$prefix1.conv.$i.sai",
		aln2         => "$prefix2.conv.$i.sai",
		fastq1       => "$prefix1.trimmed.conv.$i.fastq.gz",
		fastq2       => "$prefix2.trimmed.conv.$i.fastq.gz",
		genome       => "$METHYLCTOOLS_GENOME_DIR/$METHYLCTOOLS_REF_GENOME_CONV",
		output       => "$prefix1.conv.$i.bam",
		delete_input => 1
	);	
	
	####################################################################
	# bconv
	####################################################################
	$pipeline->set_job_name("$sample_id"."_methylctools_bconv_$i");
	$pipeline->set_job_dependency($qid->{sampe});
	$qid->{bconv} = $pipeline->methylctools->bconv(
		bam          => "$prefix1.conv.$i.bam",
		output       => "$prefix1.$i.bam",
		delete_input => 1
	);
	
	####################################################################
	# flagstat
	####################################################################
	$pipeline->set_job_name("$sample_id"."_methylctools_flagstat_$i");
	$pipeline->set_job_dependency($qid->{bconv});
	$qid->{flagstat} = $pipeline->methylctools->samtools_flagstat(
		sam          => "$prefix1.$i.bam",
		output       => "$prefix1.$i.flagstat",
		delete_input => 0
	);
	
	####################################################################
	# sort
	####################################################################
	$pipeline->set_job_name("$sample_id"."_methylctools_sort_$i");
	$pipeline->set_job_dependency($qid->{bconv});
	$qid->{sort_sam}->[$i] = $pipeline->methylctools->sort_sam(
		sam          => "$prefix1.$i.bam",
		output       => "$prefix1.sorted.$i.bam",
		delete_input => 1
	);
	$sam_sort_list->[$i] = "$prefix1.sorted.$i.bam";
}
		
########################################################################
# merge, nodup
########################################################################
$pipeline->set_job_name("$sample_id"."_methylctools_merge_and_nodup");
$pipeline->set_job_dependency(@{$qid->{sort_sam}});
$qid->{remove_duplicate} = $pipeline->methylctools->merge_nodup(
	sam_list     => $sam_sort_list,
	output       => "$prefix1.nodup.bam", 
	library      => $library,
	delete_input => 1
);

########################################################################
# insert size
########################################################################
$pipeline->set_job_name("$sample_id"."_methylctools_insertsize");
$pipeline->set_job_dependency($qid->{remove_duplicate});
$qid->{insertsize} = $pipeline->methylctools->picard_insertsize(
	sam => "$prefix1.nodup.bam"
);

########################################################################
# lambda conversion
########################################################################
$pipeline->set_job_name("$sample_id"."_methylctools_lambda_conversion");
$pipeline->set_job_dependency($qid->{remove_duplicate});
$qid->{lambda_conversion} = $pipeline->methylctools->lambda_conversion(
	bam    => "$prefix1.nodup.bam",
	output => "$prefix1.lambda.conversion.txt"
);
												 
########################################################################
# methylation calling
########################################################################
if($no_bissnp) {
	$pipeline->set_job_name("$sample_id"."_methylctools_bcall");
	$pipeline->set_job_dependency($qid->{remove_duplicate});
	$qid->{bcall} = $pipeline->methylctools->bcall(
		bam    => "$prefix1.nodup.bam",
		output => "$prefix1.call.gz"
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
	                                        
	$pipeline->set_job_name("$sample_id"."_methylctools_QC");
	$pipeline->set_job_dependency($qid->{methy_calling});
	$qid->{qc} = $pipeline->methylctools->bsqc(
		dir => $pipeline->{dir},
		tool => "methylctools",
		sample => "$sample_id",
		base_dir => $SCRIPT_DIR,
	);
	
	for my $chr (map {"chr$_"} (1..22, "X", "Y")) {
		$pipeline->set_job_name("$sample_id"."_bsseq_RData_$chr");
		$pipeline->set_job_dependency($qid->{methy_calling});
		$qid->{RData} = $pipeline->methylctools->RData(
			bedgraph   => "$prefix1.nodup.cpg.filtered.CG.bedgraph",
			sample_id  => $sample_id,
			chr        => $chr,
		);
	}
}

1;
