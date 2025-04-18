nextflow.enable.dsl=2

process MULTIQC_CUSTOM_PEAKS {
    //nfcore/chipseq
    tag "$key" 

    input:
    tuple val(key), path(peak) // from peaks_bam_ch
    path(peak_count_header) //from peak_count_header_ch

    output:
    path("*.peak_count_mqc.tsv") //into custompeaks_count_multiqc_ch

    script:
    """
    cat $peak | wc -l | awk -v OFS='\t' '{ print "${key}", \$1 }' | cat $peak_count_header - > ${key}.peak_count_mqc.tsv
    """
}