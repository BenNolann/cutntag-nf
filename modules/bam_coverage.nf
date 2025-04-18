nextflow.enable.dsl=2

process BAM_COVERAGE {
    tag "$key"
    publishDir "${params.outdir}/bamCoverage/$key", pattern:"*", mode: 'copy'

    input:
    tuple val(key), path(bam), path(bai)

    output:
    tuple val(key), path("*.bw")

    script:
    """
    bamCoverage -b $bam -o ${key}.bw --normalizeUsing BPM
    """
} 