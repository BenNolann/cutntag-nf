params.samplesheet = "${baseDir}/Samplesheets/samples_largetest_inputDependent2.csv"
params.outdir = "${baseDir}/results"
params.index = "/Zulu/bnolan/Annotations/human/Indexes/Bowtie2Index/"
params.spikeindex = "/Zulu/bnolan/Annotations/human/Indexes/Bowtie2IndexEcoli/" //doesn't exist yet
params.threads = "4"
params.ipcontrol = true
params.broad = false

include { CAT_FASTQ } from './modules/cat_fastq.nf'
include { FASTQC } from './modules/fastqc.nf'
include { TRIM_GALORE } from './modules/trim_galore.nf' //no trimming for cutntag
include { FASTQC_POST_TRIM } from './modules/fastqc_posttrim.nf'
include { ALIGN_BOWTIE2 } from './modules/align_bowtie.nf'
// include { ALIGN_SPIKEINBOWTIE2 } from './modules/align_spikein.nf'
include { SAMTOOLS_STATS_FLAGSTAT } from './modules/samtools_stats.nf'
include { SAMTOOLS_SORT } from './modules/samtools_sort.nf'
include { SAMTOOLS_SORT2 } from './modules/samtools_sort.nf'
include { DEDUP_PICARD } from './modules/dedup_picard.nf'
include { SAMTOOLS_MERGE } from './modules/samtools_merge.nf'
include { SAMTOOLS_INDEX } from './modules/samtools_index.nf'
include { BAM_COVERAGE } from './modules/bam_coverage.nf'
include { MACS3 } from './modules/macs3.nf'
include { FRiP } from './modules/frip.nf'
include { MULTIQC } from './modules/multiqc.nf'
include { MULTIQC_CUSTOM_PEAKS } from './modules/multiqc_custompeaks.nf'


log.info """\
         ===================================
         C U T & T A G - N F  P I P E L I N E    
         ===================================
         outdir       : ${params.outdir}
         samplesheet  : ${params.samplesheet}
         threads      : ${params.threads}
         index        : ${params.index}
         control      : ${params.ipcontrol}
         [true/false]
         broad  : ${params.broad}
         [true/false]
         """
         .stripIndent()

// Define main workflow
workflow {

    // Output input Samplesheet into output directory

    
    ////////////////////////////////////////////////////////
    // CONCATENATE FASTQ READS (Consider making a subworkflow)
    ////////////////////////////////////////////////////////
    // Parse the samplesheet and create initial read channel
    Channel.fromPath(params.samplesheet)
        .splitCsv(header: true, sep: ',')
        .map { row ->
            [ row.sample_id,
              [ file(row.fastq_1, checkIfExists: true), file(row.fastq_2, checkIfExists: true) ],
              row.input ]
        }
        .set { read_pairs_ch }

    // Group and branch the reads channel as before
    read_pairs_ch
        .groupTuple()
        .branch {
            meta, fastq, input ->
                single  : fastq.size() == 1
                    return [ meta, fastq.flatten(), input.flatten() ]
                multiple: fastq.size() > 1
                    return [ meta, fastq.flatten(), input.flatten() ]
        }
        .set { ch_fastq }  

    // Now call the CAT_FASTQ module by passing the appropriate channel
    // The channel from the branching is passed as a parameter to the process
    cat_out_ch = CAT_FASTQ( ch_fastq.multiple )

    // // Mix the output of CAT_FASTQ with the singles channel
    cat_out_ch.mix(ch_fastq.single)
        .set { cat_merged_ch }

    ////////////////////////////////////////////////////////
    // Perform FastQC on all samples (Single and Multiple read sets)
    fastqc = FASTQC( cat_merged_ch )

    // Use TrimGalore to trim bad reads and remove
    trim_out = TRIM_GALORE( cat_merged_ch )

    // Perform FastQC on the trimmed samples (See if it fixes any issues we had)
    fastqc_trim = FASTQC_POST_TRIM( trim_out )

    ////////////////////////////////////////////////////////
    // Alignment
    ////////////////////////////////////////////////////////
    // Initialise index channel
    index_ch = Channel.value(file(params.index))
    // Initialize spike-in channel
    index_ch_spike = Channel.value(file(params.spikeindex))

    // Align reads via Bowtie2
    ALIGN_BOWTIE2( trim_out, index_ch )
    bowtie2_reads = ALIGN_BOWTIE2.out.reads
    bowtie2_summary = ALIGN_BOWTIE2.out.summary

    // Align reads via Bowtie2 (spike-in)
    // ALIGN_SPIKEINBOWTIE2( cat_merged_ch, index_ch_spike )
    // bowtie2_reads_spike = ALIGN_SPIKEINBOWTIE2.reads
    // bowtie2_summary_spike = ALIGN_SPIKEINBOWTIE2.summary
    // bowtie2_spikedepth = ALIGN_SPIKEINBOWTIE2.spikedepth


    ////////////////////////////////////////////////////////

    // Alignment statistics
    stats_out = SAMTOOLS_STATS_FLAGSTAT( bowtie2_reads )

    // Sort bowtie2 reads
    bowtie2_sort = SAMTOOLS_SORT( bowtie2_reads )

    // Deduplicate sorted reads
    DEDUP_PICARD( bowtie2_sort )
    bowtie2_sort_dedup_bams = DEDUP_PICARD.out.bams
    bowtie2_sort_dedup_text = DEDUP_PICARD.out.text

    ////////////////////////////////////////////////////////
    // Prepare replicates in each group to be merged
    ////////////////////////////////////////////////////////
    // Combine replicates: split by '_', and group all samples
    bowtie2_sort_dedup_bams
        .map{ group_rep, bam, input ->
                            def(group) = group_rep.split("_")  
                            tuple( group, bam, input )
                            }
        .groupTuple()
        //Takes the first inputkey to avoid having nested tuples as inputkey
        .map{ group, bam, input ->
                        tuple( group, bam, input.first() )
        }
        .set{ dedup_groupsplit_ch }

    // Keep groups with more than 1 replicate, ready for combine replicates
    dedup_groupsplit_ch
            .map {
                group, bams, input -> 
                            if (bams.size() != 1){ //Only keep 'groups' with >1 replicate
                                tuple( groupKey(group, bams.size()), bams, input)
                            }
            }
            .set{ bam_sorted_groups_ch }

    // Keep the individual replicates for inputs, if group has 1 replicate
    dedup_groupsplit_ch
            .map {
                group, bams, input -> 
                            if (bams.size() == 1 & group.contains('input')){ //Only keep 'groups' with exactly 1 replicate
                                tuple( groupKey(group, bams.size()), bams, input)
                            }
                    }
            .set{bam_single_inputs_ch}
    //////////////////////////////////////////////////////

    // Merge deduplicated reads in by group
    bowtie2_sort_dedup_merged = SAMTOOLS_MERGE( bam_sorted_groups_ch ) // groups

    // Mix deduplicated merged groups, with replicates that were not merged (1 sample groups)
    bowtie2_sort_dedup_bams //deduplicated bam files
        .filter{ !it[0].contains('input') } //remove all input files
        .mix(bowtie2_sort_dedup_merged) //add merged inputs and IPs
        .mix(bam_single_inputs_ch) //add any individual replicates // this is because as we're removing all inputs previously
        .set{bams_all_ch} //all input and IP bam files: tuple [sample, bam]

    // Sort all bam files
    SAMTOOLS_SORT2( bams_all_ch )
    bams_all_sorted_winput = SAMTOOLS_SORT2.out.winput
    bams_all_sorted_noinput = SAMTOOLS_SORT2.out.noinput

    // Index the sorted deduplicated bams
    bams_all_index = SAMTOOLS_INDEX( bams_all_sorted_noinput )

    /////////////////////////////////////////////////////////////////////
    // bamCoverage
    /////////////////////////////////////////////////////////////////////
    // Add bai to bam channel for bamCoverage
    bams_all_sorted_noinput
            .join(bams_all_index)
            .set{bam_sorted_indexed_ch}

    // Generate Bigwig BPM files
    BAM_COVERAGE( bam_sorted_indexed_ch )
    /////////////////////////////////////////////////////////////////////


    /////////////////////////////////////////////////////////////////////
    // MACS3 Peak Calling
    /////////////////////////////////////////////////////////////////////
    // Setting up channels
    //MATCH INPUT TO EACH CONTROL USING THE 3RD ELEMENT IN EACH TUPLE [SAMPLE_ID, BAM, [INPUT]].

    bams_all_sorted_winput
            .branch{
                input: it[0].contains('input')
                ip: !it[0].contains('input')
            }
            .set {result}

    result.ip
            .combine(result.input) 
            .map{ip, bam, ikey, input, bam2, na2 ->
                                def ipgroup = ip.minus(~/_.*/)
                                def inputkey = ikey.first()
                                def inputgroup = input.minus(~/_.*/)

                                if(inputkey.equals(inputgroup)){
                                    tuple(ip, bam, bam2)
                                }
            }
            .set { ipbam_inputbam_ch }

    // MACS3 for peak calling
    macs3_ch = MACS3( ipbam_inputbam_ch )
    macs3_keypeak = macs3_ch.peak
    macs3_excel = macs3_ch.excel
    macs3_peakbam = macs3_ch.peakbam

    // Read in frip header for MULTIQC
    frip_score_header_ch = Channel.fromPath("$projectDir/frip_counter_header.txt", checkIfExists: true).toList()

    // Fraction of Reads inside Peaks (FRiP score)
    frip_score = FRiP( macs3_peakbam, frip_score_header_ch )

    // Read in header for MULTIQC
    peak_count_header_ch = Channel.fromPath("$projectDir/peak_count_header.txt", checkIfExists: true).toList()
    // GENERATE custom peak count entry for multiqc
    custom_peaks_multiqc = MULTIQC_CUSTOM_PEAKS(macs3_keypeak, peak_count_header_ch)

    // MULTIQC
    // Create multiqc report channel
    multiqc_ch = fastqc
                        .mix(fastqc_trim)
                        .mix(bowtie2_summary)                    
                        .mix(bowtie2_sort_dedup_text)
                        .mix(macs3_excel)
                        .mix(custom_peaks_multiqc)
                        .mix(frip_score)
                        .collect()

    // Run MULTIQC
    MULTIQC( multiqc_ch )

    // END
}
