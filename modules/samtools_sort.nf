nextflow.enable.dsl=2

process SAMTOOLS_SORT {
    tag "$key"
    publishDir "${params.outdir}/samtools/bam/${key}/", pattern:'*', mode: 'copy'

    input:
    tuple val(key), path(bam), val(input)
    
    output:
    tuple val(key), path('*sort.bam'), val(input)

    script:
    """
    samtools sort $bam > ${key}.sort.bam
    """
}

process SAMTOOLS_SORT2 {
    tag "$key"
    publishDir "${params.outdir}/samtools/bam/${key}/", pattern:'*', mode: 'copy'

    input:
    tuple val(key), path(bam), val(input)
    
    output:
    tuple val(key), path('*dedup.sort.bam'), val(input), emit: winput
    tuple val(key), path('*dedup.sort.bam'), emit: noinput

    script:
    """
    samtools sort $bam > ${key}.dedup.sort.bam
    """
}