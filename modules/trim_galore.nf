nextflow.enable.dsl=2

process TRIM_GALORE {
    tag "$key"
    publishDir "${params.outdir}/trimmed", pattern: "*.fq.gz", mode: 'copy'

    input: 
    tuple val(key), path(reads), val(input)

    output:
    tuple val(key), path("*.fq.gz"), val(input)

    script:
    """
    trim_galore \\
                --paired \\
                ${reads[0]} \\
                ${reads[1]} \\
                --basename $key \\
                --cores 1 
    """
}
