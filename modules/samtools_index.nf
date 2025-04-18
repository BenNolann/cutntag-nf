nextflow.enable.dsl=2

process SAMTOOLS_INDEX {
    tag "$key"
    publishDir "${params.outdir}/samtools/bam/${key}/", pattern:'*', mode: 'copy'

    input:
    tuple val(key), path(bam) 

    output:
    tuple val(key), path('*bai')

    script:
    """
    samtools index $bam
    """
}