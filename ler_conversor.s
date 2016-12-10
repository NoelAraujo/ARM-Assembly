// Esse programa visa pegar sinais do conversor analogico digital e exibi-los em um monitor VGA: um osciloscopio.

// -> O sinal de entrada deve estar conectado ao "Canal 1" da placa DE1-SoC
// -> A resolução VGA permitida pelo equipamento é de (320,240)
// -> A tensão medida pode ser entre 0 e 5V

// -> O algoritmo :  
// -->(1) Faço a leitura do canal de entrada
// -->(2) Converto o valor da leitura, entre (0,4095), em um valor dentro da resolução do monitor, entre (0,239)
// -->(3) Limpo a coluna vertical onde será exibido o novo ponto
// -->(4) Exibo o novo ponto 
// -->(5) Aguardo algum tempo
// -->(6) Repito o passo (1)

// Observações:
// -> Há perda de pontos devido a baixa resolução da tela. Para exibir (0,4095) em (0,239). Cada pixel na tela 
//corresponde a: 4095/239 = 17.133...
// Fazendo cada pixel na tela ser igual a 17, temos no total 17*239 = ***4063***
// Convertendo isso em volts: 
// 0 - 5V | 0 - 4095  ==> Cada 1 bit corresponde a 0.00122 V
// Bits fora da medição : (4095-4063)*0.00122 = 0.039 V
// Os ultimos 0.039 V são perdidos, esse valor não é significativo/preocupante, uma vez que o intuito desse trabalho não é ter grande precisão 

// -> Para cada ponto em X há um ponto Y no qual foi feito uma medida
// Caso seja o espaçamento entre as medidas seja feita maiores, por exemplo a cada 10 pontos em X, 
// foi implementado um "Algoritmo de Bresenham" para desenhar os pontos intermediarios
// Porem ele não foi utilizado na versão final do osciloscopio pois a baixa resolução torna a curva em tela desagradavel  



.include	"address_map_arm.s"

//##############################################################################################################
LIMPAR_TELA:
		PUSH		{R0,R2,R3,R4,R5,R6}
		LDR 		R0, 	=ADDR_VGA
		LDR 		R2,		=0				// linha 	
		LDR 		R3,		=0				// coluna

	desenhar_linha_horizontal:
		//pixel_ptr = 0xC8000000 | (row << 10) | (col << 1)
		MOV 		R4,		#0				// R4 indica a posição em memoria. Limpei ele apenas por garantia
		ORR			R4,		R0,		R2,		LSL #10
		ORR			R4,		R4,		R3,		LSL #1
		
		//[15-red-11][10-green-05][04-blue-01]
		LDR 		R5,		=0b0000000000000000			// tudo 0 = preto
		STRH 		R5,		[R4]						// armazeno MEIA PALAVRA, Half-word, no endereço R4. Por isso é necessário usar "STRH" e não "STR"
		
		ADD 		R3,		R3,		#1
		LDR			R6,		=320						// R6 é um registrador que uso para coisas temporarias
		CMP			R6,		R3
		BGT			desenhar_linha_horizontal
		BEQ			alterar_linha
		
	alterar_linha:		
		MOV			R3,		#0
		ADD 		R2,		R2,		#1
		LDR			R6,		=240					// Desenho em todas as 240 linhas, depois volto ao codigo principal
		CMP			R6,		R2
		BGT			desenhar_linha_horizontal
		POPEQ		{R0,R2,R3,R4,R5,R6}
		MOV			PC,LR

//##############################################################################################################
.macro DESENHA_PONTO regX, regY
	PUSH	{R0,R10,R11}
	LDR 	R0, 	=ADDR_VGA
	MOV 	R11,	#0					// R11 indica a posição em memoria. Limpei ele apenas por garantia
	ORR		R11,	R0,		\regY,		LSL #10
	ORR		R11,	R11,	\regX,		LSL #1
	
	LDR 	R10,	=0b111111111111111		//a escolha da cor é heuristica 
		
	STRH 	R10,	[R11]
	POP 	{R0,R10,R11}
.endm

//##############################################################################################################
// Será feita a divisão dos registradores R11 por R12, e o resultado será armazenado em R11
DIVIDIR:						 
	  PUSH	 {R0,R12}			// A operação de divisão é implementada da maneira mais simples, e não foi necessário
	  MOV     R0,#0     		// armazenar o resto da divisão
div_subtract:
	 SUBS    R11,R11,R12  
	 ADDGE   R0,R0,#1  

	 BGT     div_subtract
     MOV	 R11, R0
	 POP	 {R0,R12}
	 MOV	 PC,LR	

	
//##############################################################################################################
// Para cada novo ponto na tela, é necessário apagar o ponto anterior
// Essa função desenha uma linha vertical preta na posição X desejada
// Nada de novo a nivel de algoritmo é acrescentado nessa função

FAZER_LINHA_VERTICAL:
	PUSH 	{R0,R2,R11,R12}
	MOV 	R12,	#0				// posicao y temporario
linha_vertical_loop2:	
	LDR 	R0, 	=ADDR_VGA
	MOV 	R11,	#0				// R4 indica a posição em memoria. Limpei ele apenas por garantia
	ORR		R11,	R0,		R12,	LSL #10
	ORR		R11,	R11,	R3,		LSL #1
	
	LDR 	R2,	=0b0000000000000000
	STRH 	R2,	[R11]
	
	ADD 	R12,		R12,		#1
	CMP		R12,		#239
	BLT 	linha_vertical_loop2
	
	POP 	{R0,R2,R11,R12}
	MOV	 	PC,LR


	
//##############################################################################################################	
.text
.global _start
_start:

/* Registadores:
R3 = X
R4 = Y
*/
	MOV    SP, 	#DDR_END - 3
	BL		LIMPAR_TELA

	
/* Coisas pra fazer o timer funcionar, esse código foi aproveitado de um dos exemplos do proprio Programa Universitario */	
	LDR 	R9, =MPCORE_PRIV_TIMER		    // MPCore private timer base address
	LDR		R10, =5000000					// timeout = 1/(200 MHz) x 200x10^6 = 1 sec *** Eu modifiquei esse valor para ser mais rapido a aquisição dos dados
	STR		R10, [R9]						// write to timer load register
	MOV		R10, #0b011						// set bits: mode = 1 (auto), enable = 1
	STR		R10, [R9, #0x8]					// write to timer control register
	
	LDR    R6,  =ADC0                       // Para ler no conversor, eu preciso configurar-lo para dar auto-update
	MOV	   R11,	#1                          // Para tal,escrevo 1 no canal 1
	STR    R11, [R6,#4]
	
    BL      inicializar_xy                   // configura o valor inicial de (x,y) em (0,239)  
    
desenhar_leitura:	
	// a posicao X muda em unidades, ou seja, de um em um.     
	ADD	   R3,	R3,		#1					// Posição X = colunas

    BL FAZER_LINHA_VERTICAL					//Apago a coluna atual antes de desenhar um novo ponto nela
//######################## Pego um novo ponto e faço ele caber na tela ###########################
    CMP	   R3,	#320	                    // maximo valor em X na tela (Resolução de 320,240)
	BGE	   inicializar_xy					// Se R3 == 320, significa que a tela foi preenchida por completo, e a posição de X deve ser inicializada
	
	LDR    R6,  =ADC0                       // irei efetuar a leitura do primeiro canal (channel 1).
	MOV	   R11,	#0                          // Como a leitura ira retonar 12 bits, eu coloco zero no registrador apenas por garantia 
	
    LDR    R11, [R6,#4]						 Para ler outros canais, por exemplo o canal 2, basta mudar o "#4" para "#8", etc.
    MOV	   R12,	#17                         // Pego o valor entre (0,4095) do ADC e preciso coloca-lo na tela, de resolução (320,240).
                                            // 4095/239 = 17.33 | 17*239 = 4063.--> Preciso dividir por 17
											
	BL	   DIVIDIR                          // Divide R11/R2 e deixa a resposta em R11
	MOV	   R4,	R11                         // R11 é apenas temporario, R4 é o registrador que eu devo utilizar para desenhar pontos
	
    // O ponto (0,0) esta no canto superior da tela, para tornar a leitura dos dados mais intuitiva, eu preciso inverter sua posição
    // Ex: Se eu quero que um valor "10" esteja no canto inferior da tela, seu valor deve ser "229" : 239-10 = 229  
	LDR	   R6, =239    
	SUB	   R4,  R6, R4
//######################## Pego o novo ponto e faço ele caber na tela ###########################
	DESENHA_PONTO R3, R4
	
WAIT:										// Espero um tempo antes de realizar a proxima leitura
	LDR		R10, [R9, #0xC]					// read timer status
	CMP		R10, #0
	BEQ		WAIT
	STR		R10, [R9, #0xC]					// reset timer flag bit	
	B 	    desenhar_leitura
		
inicializar_xy:
		LDR    R3, 	=0		// x1
		LDR    R4, 	=239	// y1
		B desenhar_leitura

		
	.end