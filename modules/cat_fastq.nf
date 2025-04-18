nextflow.enable.dsl=2

process CAT_FASTQ {
    //nf-core
    tag "${sample_id}"
    publishDir "${params.outdir}/fastqMerged", mode: 'copy'

    input:
    tuple val(sample_id), path(reads, stageAs: "input*/*"), val(input)
    
    output:
    tuple val(sample_id), path("*.merged.fastq.gz"), val(input)


    script:
    def readList = reads instanceof List ? reads.collect{ it.toString() } : [reads.toString()]

     if (readList.size >= 2) {
        def read1 = []
        def read2 = []
        readList.eachWithIndex{ v, ix -> ( ix & 1 ? read2 : read1 ) << v }

        """
        cat ${read1.join(' ')} > ${sample_id}_1.merged.fastq.gz
        cat ${read2.join(' ')} > ${sample_id}_2.merged.fastq.gz
        """  
     }
}

