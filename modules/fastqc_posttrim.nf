nextflow.enable.dsl=2

process FASTQC_POST_TRIM {
    tag "$sample_id"
    publishDir "${params.outdir}/fastqc_trimmed", pattern:"{*.html,${sample_id}}", mode: 'copy'

    input:
    tuple val(sample_id), path(reads), val(input)

    output:
    path("${sample_id}") 

    script:
    """
    mkdir ${sample_id}
    fastqc -o ${sample_id} -f fastq -q ${reads}
    """  
}