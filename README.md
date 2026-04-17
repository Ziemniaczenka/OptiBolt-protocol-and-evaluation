# OptiBolt - Protocol and Evaluation

**Autorzy:** *Tomasz Więcławski (@TomaszWieclawski), Sebastian Zoń (@Ziemniaczenka)*

## Opis projektu

*Tu będzie opis*


## TODO

<details open>
<summary><b><big> Lista Zadań </big></b></summary>


*   <details open>
    <summary><b>Dokumentacja i konfiguracja </b></summary>

    - [x] Ustalić nazwę projektu
    - [ ] Krótki opis
    - [ ] Git
      - [x] Stworzyć Repo
      - [ ] Dowiedzieć się jak działają pull request i review
    - [x] Napisać README
    - [x] Dodać referencyjne dokumenty (np. zielony pdf z konwencjami)
    - [ ] VSCode settings + formatter config
    - [ ] Nauczyć się Markdown i Mermaid

    </details>

*   <details open>
    <summary><b>Hardware</b></summary>

    - [x] Znaleźć złącze
    - [x] Narysować schemat
    - [ ] Zamówić brakujące części
    - [ ] Zlutować
    </details>

*   <details open>
    <summary><b>SystemVerilog </b></summary>

    - [ ] Podział na moduły, diagram
    - [ ] Testbenche do każdej grupy modułów/do każdego modułu?
    - [ ] Ustalenie Clock domains
      - [ ] CDC pomiędzy sekcjami
    - [ ] SystemVerilog OOP (Object Oriented Programming)?
    - [ ] UVM - Universal Verification Methodology - test for testbenches?
      - [ ] Aktualizacja skryptów do UVM?
    </details>

*   <details open>
    <summary><b>Protokół</b></summary>

    - [ ] Założenia, teoria
    - [ ] Warstwy modelu
    - [ ] Flowchart, Sequence diagrams
    </details>

*   <details open>
    <summary><b>Program testowy</b></summary>

    - [ ] Wyświetlanie VGA
      - [ ] Double frame buffer
      - [ ] VGA Parameters include 
      - [ ] Rysowanie znaków?
      - [ ] DrawString?
      - [ ] FontLibrary?
      - [ ] DrawChart?
    - [ ] Obsługa klawiatury
    - [ ] Różne testy (max baudrate, BER, latency, wysyłanie wiadomości, itd)
    </details>

</details>

## Narzędzia i materiały dodatkowe

<details open>
<summary><b><big> Lista Narzędzi </big></b></summary>

*   <details open>
    <summary><big>VSCode </big></summary>
    
    * **Rozszerzenia**
      * SystemVerilog
        * Verilog-HDL/SystemVerilog/Bluespec SystemVerilog by Masahiro Hiramori
          * Verible
        * DVT IDE for Verilog/SystemVerilog/VHDL/e Language by AMIQ EDA s.r.l.
          * Dostępne tylko w pracowni!
      * Dokumentacja
        * Markdown
          * Markdown All in One
          * Markdown Preview Mermaid Support
        * vscode-pdf
        * TIFF Preview
        * Docx/ODT Viewer
        
      * Git
        * GitHub Pull Requests

    </details>

*   <details open>
    <summary><big>Materiały dodatkowe </big></summary>
    
    * **Zasady kodowania**
      * [wikiMTM](https://wiki.mtm.agh.edu.pl/pl/students/courses/uec/sv-rtl-coding-rules)
      * [PDF](doc/mtm-digital-guidelines.pdf)
  
    * **SystemVerilog**
      * [ChipVerify Tutorial](https://www.chipverify.com/systemverilog/systemverilog-tutorial)
      * OOP
        * [CV Classes](https://www.chipverify.com/systemverilog/systemverilog-class)
      * CDC (Clock Domain Crossing)
        * [CV CDC](https://www.chipverify.com/rtl-synthesis/clock-domain-crossing)
        * [MTM wiki](https://wiki.mtm.agh.edu.pl/pl/students/courses/uec/cdc)
      * UVM
        * <details>
          <summary><a href="https://www.chipverify.com/uvm/uvm-tutorial">CV OVM Tutorial</a></summary>

          * >**Common Beginner Mistakes:**\
            Mistake #1: Trying to Learn UVM Without SystemVerilog OOP\
            Mistake #2: Reading the UVM Reference Manual First\
            Mistake #3: Trying to Understand All of UVM at Once\
            Mistake #4: Not Running Code While Learning
          * > **UVM Learning Curve in Industry**\
            Professional verification teams typically train new engineers with this timeline:<br> 
            **Week 1-2:** SystemVerilog OOP refresher and basic UVM concepts.<br> 
            **Week 3-4:** Build a simple UVM testbench from scratch (UART, I2C, SPI).<br> 
            **Week 5-8:** Work on a real project under mentorship, extending existing environments.<br> 
            **Month 3-6:** Independent contribution to verification IP development. Most engineers become proficient within 6 months of hands-on practice, even without prior UVM experience—if they have strong SystemVerilog foundations.
          </details>         
  
        * [Vivado docs](https://docs.amd.com/r/en-US/ug900-vivado-logic-simulation/Vivado-Simulator-Compilation-Options)  
    * **Basys 3**
      * [Reference manual](https://digilent.com/reference/programmable-logic/basys-3/reference-manual)
    * **Informacje na temat protokołu**
      * [Hardware 1](https://vksdr.com/pmod/)   
      * [Hardware 2](https://tomverbeure.github.io/2021/01/18/SPDIF-Output-PMOD.html)   
      * [Toslink info](https://w2.electrodragon.com/Network-dat/fiber-optic-dat/TOSLINK-dat/TOSLINK-dat.md)
    * **Git**
      * [Poradnik gita](https://git-scm.com/book/pl/v2)
    * **Markdown**
      * GitHub Flavored Markdown
        * [Tutorial](https://docs.github.com/en/get-started/writing-on-github)
      * Mermaid
        * [Online editor](https://mermaid.ai/live/)
        * [Docs](https://mermaid.js.org/intro/)
    * **Grafiki**
      * [Lopaka - pixelart](https://lopaka.app/)

    </details>

</details>

## Architektura Sprzętowa

<details open>
<summary><b><big>Schemat Blokowy Połączeń </big></b></summary>

```mermaid
---
title: Schemat Blokowy
---
flowchart LR
  %%{init: {'flowchart': {'curve': 'linear'}}}%%

  %% --- Left Board ---

  Disp1[Display] --> |VGA| Basys1 
  Kb1[Keyboard] <--> |USB| Basys1

  subgraph Basys1[Basys 3]
    direction TB
    CPU1[Artix 7]
    CPU1 --> D1[Diodes]
    CPU1 --> 7seg1[7seg]
    CPU1 --> B1[Buttons]
    CPU1 --> Sw1[Switches]
  end

  %% --- Left OptiBolt ---
  subgraph OB1[OptiBolt]
    direction LR
    Tx1[Tx]
    Rx1[Rx]
  end

  Basys1 <--> |PMOD| OB1

  %% --- Right OptiBolt ---
  subgraph OB2[OptiBolt]
    direction LR
    Rx2[Rx]
    Tx2[Tx]
  end

  %% --- Central Optical Link ---
  Tx1 ==> |TOSLINK| Rx2 
  Rx1 ~~~  Tx2 ==> |TOSLINK| Rx1 
  Tx2 ~~~ Rx1

  OB2 <--> |PMOD| Basys2

  %% --- Right Board ---

  subgraph Basys2[Basys 3]
    direction TB
    CPU2[Artix 7]
    CPU2 --> D2[Diodes]
    CPU2 --> 7seg2[7seg]
    CPU2 --> B2[Buttons]
    CPU2 --> Sw2[Switches]
  end
  
  Basys2 --> |VGA| Disp2[Display]
  Basys2 <--> |USB| Kb2[Keyboard]
```

</details>

<details open>
<summary><b><big>Schemat Modułu OptiBolt PMOD </big></b></summary>

<!-- Dwa pliki z odwróconym kolorem dla jasnego i ciemnego motywu -->

![OptiBolt transceiver schematic](/doc/schematic/OptiBolt_transceiver_light.svg#gh-light-mode-only)
![OptiBolt transceiver schematic](/doc/schematic/OptiBolt_transceiver_dark.svg#gh-dark-mode-only)

</details>

## Architektura Ogólna
<details open>
<summary><b><big>Schemat Połączeń Między Sekcjami </big></b></summary>

``` mermaid
  flowchart LR
    %%{init: {'flowchart': {'curve': 'linear'}}}%%

    %% Modules

    VGA[VGA]
    
    Eval[Evaluation 
    Platform]
    Eval@{shape: hex}
    style Eval font-size:24px

    OptiBolt[OptiBolt 
    Protocol]
    OptiBolt@{shape: hex}
    style OptiBolt font-size:24px

    Tx["OptiBolt Tx"]
    Rx["OptiBolt Rx"]

    %% Connections
    VGA ~~~ Eval
    Eval ===>|VGA_if| VGA


    Eval --> |"Sygnał [3:0] "| OptiBolt
    OptiBolt ==>|magistrala| Eval

    OptiBolt -->|JB1:A14| Tx
    OptiBolt ~~~ Rx 
    Rx--> |JB3:B15| OptiBolt
    Rx ~~~ OptiBolt

```
</details>


## Architektura Protokołu OptiBolt

## Architektura Platformy Ewaluacji

