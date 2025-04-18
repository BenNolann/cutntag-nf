nextflow.enable.dsl=2

// Samtools stats for summary statistics on alignment
process SAMTOOLS_STATS_FLAGSTAT {
    tag "$key"
    publishDir "${params.outdir}/samtools/stats/", pattern:'*', mode: 'copy'

    input:
    tuple val(key), path(bam), val(input)

    output:
    path('*stats') 
    path('*flagstat') 


    script:
    """
    samtools stats --threads ${params.threads} \\
                   $bam \\
                   > ${key}.stats

    samtools flagstat \\
                        --threads ${params.threads} \\
                        $bam \\
                        > ${key}.flagstat

    """
}