nextflow.enable.dsl=2

process DEDUP_PICARD{
    tag "$key"
    publishDir "${params.outdir}/picard/$key", pattern:"*", mode: 'copy'

    input:
    tuple val(key), path(bam), val(input)
    
    output:
    tuple val(key), path("*.dedup.bam"), val(input), emit: bams
    path("*.MarkDuplicates.metrics.txt"), emit: text

    script:
    """
    PicardCommandLine \\
        MarkDuplicates \\
        INPUT=$bam \\
        OUTPUT=${key}.dedup.bam \\
        REMOVE_DUPLICATES=true \\
        METRICS_FILE=${key}.MarkDuplicates.metrics.txt
    """
}