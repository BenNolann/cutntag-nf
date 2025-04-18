nextflow.enable.dsl=2

process MULTIQC {
    publishDir "${params.outdir}/multiqc/", pattern:"multiqc_report.html", mode:'copy'
       
    input:
    path('*', stageAs: "?/*") //from multiqc_ch
    
    output:
    path('multiqc_report.html')  
     
    script:
    """
    multiqc . 
    """
} 