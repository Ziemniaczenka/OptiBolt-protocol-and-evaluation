# OptiBolt - Protocol and Evaluation

**Autorzy:** *Tomasz Więcławski (@TomaszWieclawski), Sebastian Zoń (@Ziemniaczenka)*

## Opis projektu

  Prototyp hybrydowgo protokołu komunikacji OptiBolt i platforma ewaluacyjna.

  Protokół fizycznie składa się z części elektrycznej (emulowanej) oraz światłowodowej (zrealizowanej na transcieverach TOSLINK).

  Platforma ewaluacyjna obsługuje podłącznie klawiatury i interfejsu VGA, służy do przeprowadzania testów interfejsu i wyświetlania rezultatów.


## TODO

<details open>
<summary><b><big> Lista Zadań </big></b></summary>

*   <details open>
    <summary><b>Harmonogram </b></summary>

    | Date | Week | Task | Who | Status |
    |:---:  | :---: | :---                                                | :---:             | :---:   |
    | 13.04 | 1 | Inicjalizacja projektu, dobór elementów                 | Wszyscy           | 🟢 Done |
    | 20.04 | 2 | Funkcja drawstring                                      | @Ziemniaczenka    | 🟢 Done |
    | 27.04 | 3 | Schematy w readme                                       | @Ziemniaczenka    | 🟢 Done |
    | 27.04 | 3 | Zarys protokołu                                         | @TomaszWieclawski | 🟢 Done |
    | 4.05  | 4 | PRZERWA (Egzamin 0 UEA2)                                | @Ziemniaczenka    | 🟢 Done |
    | 11.05 | 5 | Pozostałe funkcje draw, top_draw                        | @Ziemniaczenka    | 🟡 WiP  |
    | 11.05 | 5 | Ustalenie parametrów i sygnałów sterujących protokołu   | @TomaszWieclawski | 🟡 WiP  |
    | 18.05 | 6 | Klawiatura, wiersz poleceń                              | @Ziemniaczenka    | 🟡 WiP  |
    | 18.05 | 6 | Przerobienie modułu UART na OptiBolt                    | @TomaszWieclawski | 🟡 WiP  |
    | 25.05 | 7 | Złożenie hardware, generacja bitstreamu, pierwsze testy | Wszyscy           | 🟡 WiP  |
    | 01.06 | 8 | Integracja protokołu z ewaluacją                        | Wszyscy           | 🔴 TODO |
    | 08.06 | 9 | Testy końcowe i finalizacja dokumentacji                | Wszyscy           | 🔴 TODO |
    | 15.06 | 10| 16.06 PIERWSZY TERMIN ODDANIA PROJEKTU                  | Wszyscy           | 🔴 TODO |
    </details>

    <details open>
    <summary><b>Lista pytań </b></summary>

    - Czy możemy korzystać z innych modułów?
      - VHDL od myszki np.
      - Verilog od UART
      - SystemVerilog z internetu
      - TAK
    - Jaki reset ma być?
      - Asynchroniczny zanegowany (rst_n)
    - Czy wyjścia z modułów mają być rejestrowalne?
      - Powinny być chyba że jest konkretny powód by nie były
    - Czy vivado sprawdza timing violation by default 
      - Tak
    - Czy dokumentacja końcowa może być w Markdown zamiast DOCX?
      - może być ale wyeksportowany do PDFa

    </details>

*   <details open>
    <summary><b>Dokumentacja i konfiguracja </b></summary>

    - [x] Ustalić nazwę projektu
    - [x] Krótki opis
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
    - [x] Zamówić brakujące części
    - [x] Zlutować
    </details>

*   <details open>
    <summary><b>SystemVerilog </b></summary>

    - [ ] Podział na moduły, diagram
    - [ ] Testbenche do grup modułów
    - [x] Sprawdzić czy Vivado robi timing analisys by default
    - [ ] Ustalenie Clock domains
      - [ ] CDC pomiędzy sekcjami
    </details>

*   <details open>
    <summary><b>Protokół</b></summary>

    - [x] Założenia, teoria
    - [ ] Manchester encoder/decoder
    - [ ] Ustalić zakres BAUDRATE i Oversampling, min and max speed
      - [ ] tabela dopuszczalnych (lookup table)
      - [ ] enumy do maszyn stanów (IDLE, PREAMBLE, ERROR itp.)
    - [ ] Warstwy modelu
    - [ ] Rejestry konfiguracyjne do protokołu
      - [ ] np. Baudrate
      - [ ] sygnały sterujące (np. zmień baudrate)
        - [ ] odpowiedź zwrotna (wait, success, error)
    - [ ] Flowchart, Sequence diagrams
    </details>

*   <details open>
    <summary><b>Program testowy</b></summary>

    - [ ] Wyświetlanie VGA
      - [x] VGA Parameters include 
      - [ ] Ustalenie layoutu ekranu
      - [x] DrawBitmap
      - [x] DrawRect
      - [x] DrawString
        - [ ] Improve code
        - [ ] Make output registerable (add one cycle delay)
        - [ ] Add more fonts
      - [ ] DrawChart
    - [ ] Obsługa klawiatury
    - [ ] Różne testy (max baudrate, BER, latency, wysyłanie wiadomości, itd.)
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
      * CDC (Clock Domain Crossing)
        * [CV CDC](https://www.chipverify.com/rtl-synthesis/clock-domain-crossing)
        * [MTM wiki](https://wiki.mtm.agh.edu.pl/pl/students/courses/uec/cdc)
      * OOP (not relevant)
        * [CV Classes](https://www.chipverify.com/systemverilog/systemverilog-class)
      * UVM (not relevant)
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
title: Schemat Blokowy Połączeń
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
<summary><b><big>Schemat Połączeń Między Sekcjami (WiP) </big></b></summary>

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

    Tx["OptiBolt Tx
        JB1:A14"]
    Rx["OptiBolt Rx
        B3:B15"]
    PlugDetect["PlugDetect
        (Switch 1)"]
    

    %% Connections TODO: zgodne nazwy portów i połączeń, pozostałe moduły

    VGA ~~~ Eval
    Eval ===>|VGA_if| VGA


    %% Tu opisać wszystkie połączenia między Eval a OptiBolt
    Eval --> |"Sygnał [3:0] "| OptiBolt
    OptiBolt ==>|magistrala| Eval

    OptiBolt ~~~ Rx 
    OptiBolt -->|Tx| Tx
    OptiBolt ~~~ Rx 
    Rx--> |Rx| OptiBolt
    %%Rx ~~~ OptiBolt
    OptiBolt ~~~ PlugDetect 
    
    PlugDetect -->|PlugDetect| OptiBolt
    PlugDetect ~~~ OptiBolt

```
</details>


## Architektura Protokołu OptiBolt

## Architektura Platformy Ewaluacji
<details open>
<summary><b><big>Schemat Platformy Ewaluacji (WiP) </big></b></summary>

```mermaid
---
title: Architektura Platformy Ewaluacji
---
flowchart LR
  %%{init: {'flowchart': {'curve': 'linear'}}}%%

  subgraph top_display
    %% --- VGA ---
    vga_pkg.sv

    subgraph top_VGA.sv
      vga_timing.sv
      vga_draw.sv
    end

    subgraph top_interface.sv
      interface_fsm.sv
    end
      

  
    display_buffer.sv
    draw_graph.sv
    draw_rect.sv
    draw_line.sv

    subgraph write_string.sv
      write_char.sv
      font.sv
    end

  end
  subgraph top_keyboard.sv
    read_command.sv

  end
  subgraph top_test.sv
    test_fsm.sv
    BER_test.sv
    bandwidth_test.sv
  end


```
</details>

<details open>
<summary><b><big>Opis Funkcjonalności Głównych bloków (WiP) </big></b></summary>

  * Tests:
    * `top_test.sv`
      * description
    * `test_fsm.sv`
      * managing running multiple tests, solving conflicts
  * Keyboard:
    * `read_command.sv`
      * read arrow key inputs in interface
      * read input letters from keyboard to either run tests or send message to second board
  * Display:
    * `top_draw.sv`
      * Main VGA module with interface displayed 

</details>