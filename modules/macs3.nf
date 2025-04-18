nextflow.enable.dsl=2

process MACS3 {
    tag "$key"
    publishDir "${params.outdir}/macs3/$key", pattern:"*", mode: 'copy'

    input:
    tuple val(key), path(bamip), path(baminput)

    output:
    tuple val(key), path("*eak"), emit: peak
    tuple val(key), path("*eak"), path(bamip), emit: peakbam
    path("*.xls"), emit: excel
    path("*"), emit: allelse

    script:
    def control_input = params.ipcontrol ? -c $baminput : ''

    """
    macs3 \\
            callpeak \\
            -t $bamip \\
            ${control_input} \\
            -n $key \\
            -g hs \\
            --call-summits
    """ 


    // if ( params.ipcontrol == true )
    //     """
    //     macs3 \\
    //             callpeak \\
    //             -t $bamip \\
    //             -c $baminput \\
    //             -n $key \\
    //             -g hs \\
    //             --call-summits
    //     """ 

    // else if ( params.ipcontrol == false)
    //     """
    //     macs3 \\
    //             callpeak \\
    //             -t $bamip \\
    //             -n $key \\
    //             -g hs \\
    //             --call-summits
    //     """ 

    // else
    //     error "Invalid MACS3 control mode: ${params.ipcontrol} | Expects true/false"
}