nextflow.enable.dsl=2

process ALIGN_SPIKEINBOWTIE2 {
    tag "$key"
    publishDir "${params.outdir}/alignment/$key/", pattern:'{*.log, *.bam, *seqDepth}', mode: 'copy'

    input:
    tuple val(key), path(reads), val(input)
    path(index) // E.coli index

    output:
    tuple val(key), path("*bam"), val(input), emit: reads
    path("*.bowtie2.log"), emit: summary
    path("*.bowtie2_spikeIn.seqDepth"), emit: spikedepth

    script:

        """
        # bowtie2 parameters obtained from
        # https://yezhengstat.github.io/CUTTag_tutorial/#II_Data_Pre-processing

        INDEX=`find -L ./ -name "*.rev.1.bt2" | sed "s/.rev.1.bt2//"`
        [ -z "\$INDEX" ] && INDEX=`find -L ./ -name "*.rev.1.bt2l" | sed "s/.rev.1.bt2l//"`
        [ -z "\$INDEX" ] && echo "Bowtie2 index files not found" 1>&2 && exit 1

        bowtie2 \\
                -x \$INDEX \\
                --end-to-end \\ 
                --very-sensitive \\
                --no-mixed \\
                --no-discordant \\
                --phred33 -I 10 -X 700 \\
                --no-overlap \\
                --no-dovetail \\
                --threads $params.threads \\
                -1 ${reads[0]} \\
                -2 ${reads[1]} \\
                2> ${key}.bowtie2.log \\
                | samtools view -@ $params.threads -bhS -q 10 -o ${key}.bam -

        seqDepthDouble=`samtools view -F 0x04 ${key}.bam`
        seqDepth=$((seqDepthDouble/2))
        echo $seqDepth > ${key}.bowtie2_spikeIn.seqDepth
        """  
}