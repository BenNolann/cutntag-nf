nextflow.enable.dsl=2

process SAMTOOLS_MERGE {
    tag "$group"
    publishDir "${params.outdir}/samtools/merge/${group}/", pattern:'*', mode: 'copy'

    input:
    tuple val(group), path(bams), val(input)

    output:
    tuple val(group), file("*.merged.bam"), val(input)

    script:
    """
    samtools merge -n ${group}.merged.bam $bams 
    """
}