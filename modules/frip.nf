nextflow.enable.dsl=2

process FRiP {
    tag "$key"
    publishDir "${params.outdir}/FRiP/$key/", pattern:'*.frip_score_mqc.tsv', mode: 'copy'

    input:
    tuple val(key), path(peak), path(bam)
    path(frip_score_header)

    output:
    path("*.frip_score_mqc.tsv")

    script:
    """
    READS_IN_PEAKS=\$(intersectBed -bed -a $bam -b $peak | wc -l)
    samtools flagstat $bam > ${bam}.flagstat
    grep 'mapped (' ${bam}.flagstat | grep -v "primary" | awk -v a="\$READS_IN_PEAKS" -v OFS='\t' '{print "${key}", a/\$1}' | cat $frip_score_header - > ${key}.frip_score_mqc.tsv
    """
}