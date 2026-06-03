Benchmark

Benchmark run from 2026-06-03 12:08:03.181281Z UTC

## System

Benchmark suite executing on the following system:

<table style="width: 1%">
  <tr>
    <th style="width: 1%; white-space: nowrap">Operating System</th>
    <td>macOS</td>
  </tr><tr>
    <th style="white-space: nowrap">CPU Information</th>
    <td style="white-space: nowrap">Apple M4 Pro</td>
  </tr><tr>
    <th style="white-space: nowrap">Number of Available Cores</th>
    <td style="white-space: nowrap">12</td>
  </tr><tr>
    <th style="white-space: nowrap">Available Memory</th>
    <td style="white-space: nowrap">24 GB</td>
  </tr><tr>
    <th style="white-space: nowrap">Elixir Version</th>
    <td style="white-space: nowrap">1.19.1</td>
  </tr><tr>
    <th style="white-space: nowrap">Erlang Version</th>
    <td style="white-space: nowrap">28.1.1</td>
  </tr>
</table>

## Configuration

Benchmark suite executing with the following configuration:

<table style="width: 1%">
  <tr>
    <th style="width: 1%">:time</th>
    <td style="white-space: nowrap">10 s</td>
  </tr><tr>
    <th>:parallel</th>
    <td style="white-space: nowrap">20</td>
  </tr><tr>
    <th>:warmup</th>
    <td style="white-space: nowrap">2 s</td>
  </tr>
</table>

## Statistics



Run Time

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Devitation</th>
    <th style="text-align: right">Median</th>
    <th style="text-align: right">99th&nbsp;%</th>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 1kb</td>
    <td style="white-space: nowrap; text-align: right">3.76 K</td>
    <td style="white-space: nowrap; text-align: right">0.27 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;23.08%</td>
    <td style="white-space: nowrap; text-align: right">0.26 ms</td>
    <td style="white-space: nowrap; text-align: right">0.43 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 10kb</td>
    <td style="white-space: nowrap; text-align: right">3.12 K</td>
    <td style="white-space: nowrap; text-align: right">0.32 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;24.06%</td>
    <td style="white-space: nowrap; text-align: right">0.31 ms</td>
    <td style="white-space: nowrap; text-align: right">0.52 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 1kb</td>
    <td style="white-space: nowrap; text-align: right">1.87 K</td>
    <td style="white-space: nowrap; text-align: right">0.53 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;14.07%</td>
    <td style="white-space: nowrap; text-align: right">0.53 ms</td>
    <td style="white-space: nowrap; text-align: right">0.72 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 10kb</td>
    <td style="white-space: nowrap; text-align: right">1.82 K</td>
    <td style="white-space: nowrap; text-align: right">0.55 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;16.48%</td>
    <td style="white-space: nowrap; text-align: right">0.55 ms</td>
    <td style="white-space: nowrap; text-align: right">0.78 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 100kb</td>
    <td style="white-space: nowrap; text-align: right">0.88 K</td>
    <td style="white-space: nowrap; text-align: right">1.14 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;26.16%</td>
    <td style="white-space: nowrap; text-align: right">1.10 ms</td>
    <td style="white-space: nowrap; text-align: right">1.96 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 100kb</td>
    <td style="white-space: nowrap; text-align: right">0.49 K</td>
    <td style="white-space: nowrap; text-align: right">2.03 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;13.91%</td>
    <td style="white-space: nowrap; text-align: right">2.02 ms</td>
    <td style="white-space: nowrap; text-align: right">2.74 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 1mb</td>
    <td style="white-space: nowrap; text-align: right">0.100 K</td>
    <td style="white-space: nowrap; text-align: right">9.95 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;23.79%</td>
    <td style="white-space: nowrap; text-align: right">9.72 ms</td>
    <td style="white-space: nowrap; text-align: right">16.51 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 1mb</td>
    <td style="white-space: nowrap; text-align: right">0.0590 K</td>
    <td style="white-space: nowrap; text-align: right">16.95 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;9.96%</td>
    <td style="white-space: nowrap; text-align: right">17.14 ms</td>
    <td style="white-space: nowrap; text-align: right">21.94 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">http1 1kb</td>
    <td style="white-space: nowrap;text-align: right">3.76 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 10kb</td>
    <td style="white-space: nowrap; text-align: right">3.12 K</td>
    <td style="white-space: nowrap; text-align: right">1.2x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 1kb</td>
    <td style="white-space: nowrap; text-align: right">1.87 K</td>
    <td style="white-space: nowrap; text-align: right">2.01x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 10kb</td>
    <td style="white-space: nowrap; text-align: right">1.82 K</td>
    <td style="white-space: nowrap; text-align: right">2.07x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 100kb</td>
    <td style="white-space: nowrap; text-align: right">0.88 K</td>
    <td style="white-space: nowrap; text-align: right">4.27x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 100kb</td>
    <td style="white-space: nowrap; text-align: right">0.49 K</td>
    <td style="white-space: nowrap; text-align: right">7.63x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 1mb</td>
    <td style="white-space: nowrap; text-align: right">0.100 K</td>
    <td style="white-space: nowrap; text-align: right">37.42x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 1mb</td>
    <td style="white-space: nowrap; text-align: right">0.0590 K</td>
    <td style="white-space: nowrap; text-align: right">63.69x</td>
  </tr>

</table>



Memory Usage

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">http1 1kb</td>
    <td style="white-space: nowrap">7.88 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 10kb</td>
    <td style="white-space: nowrap">8.75 KB</td>
    <td>1.11x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 1kb</td>
    <td style="white-space: nowrap">0.77 KB</td>
    <td>0.1x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 10kb</td>
    <td style="white-space: nowrap">0.77 KB</td>
    <td>0.1x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 100kb</td>
    <td style="white-space: nowrap">18.47 KB</td>
    <td>2.35x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 100kb</td>
    <td style="white-space: nowrap">0.74 KB</td>
    <td>0.09x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 1mb</td>
    <td style="white-space: nowrap">234.99 KB</td>
    <td>29.84x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 1mb</td>
    <td style="white-space: nowrap">0.77 KB</td>
    <td>0.1x</td>
  </tr>
</table>



Reduction Count

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">http1 1kb</td>
    <td style="white-space: nowrap">830.02</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 10kb</td>
    <td style="white-space: nowrap">967.35</td>
    <td>1.17x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 1kb</td>
    <td style="white-space: nowrap">25.00</td>
    <td>0.03x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 10kb</td>
    <td style="white-space: nowrap">25.00</td>
    <td>0.03x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 100kb</td>
    <td style="white-space: nowrap">2385.90</td>
    <td>2.87x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 100kb</td>
    <td style="white-space: nowrap">25.00</td>
    <td>0.03x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 1mb</td>
    <td style="white-space: nowrap">18163.84</td>
    <td>21.88x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 1mb</td>
    <td style="white-space: nowrap">32.00</td>
    <td>0.04x</td>
  </tr>
</table>