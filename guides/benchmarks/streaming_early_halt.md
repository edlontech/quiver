Benchmark

Benchmark run from 2026-03-06 20:34:48.118740Z UTC

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
    <td style="white-space: nowrap">10</td>
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
    <td style="white-space: nowrap">http1 stream take 1</td>
    <td style="white-space: nowrap; text-align: right">167.48</td>
    <td style="white-space: nowrap; text-align: right">5.97 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;14.06%</td>
    <td style="white-space: nowrap; text-align: right">5.82 ms</td>
    <td style="white-space: nowrap; text-align: right">8.60 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 collect 1mb</td>
    <td style="white-space: nowrap; text-align: right">160.58</td>
    <td style="white-space: nowrap; text-align: right">6.23 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;14.18%</td>
    <td style="white-space: nowrap; text-align: right">6.08 ms</td>
    <td style="white-space: nowrap; text-align: right">8.92 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 stream take 1</td>
    <td style="white-space: nowrap; text-align: right">110.06</td>
    <td style="white-space: nowrap; text-align: right">9.09 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;16.75%</td>
    <td style="white-space: nowrap; text-align: right">9.41 ms</td>
    <td style="white-space: nowrap; text-align: right">11.44 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 collect 1mb</td>
    <td style="white-space: nowrap; text-align: right">108.81</td>
    <td style="white-space: nowrap; text-align: right">9.19 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;14.72%</td>
    <td style="white-space: nowrap; text-align: right">8.54 ms</td>
    <td style="white-space: nowrap; text-align: right">12.25 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">http1 stream take 1</td>
    <td style="white-space: nowrap;text-align: right">167.48</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 collect 1mb</td>
    <td style="white-space: nowrap; text-align: right">160.58</td>
    <td style="white-space: nowrap; text-align: right">1.04x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 stream take 1</td>
    <td style="white-space: nowrap; text-align: right">110.06</td>
    <td style="white-space: nowrap; text-align: right">1.52x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 collect 1mb</td>
    <td style="white-space: nowrap; text-align: right">108.81</td>
    <td style="white-space: nowrap; text-align: right">1.54x</td>
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
    <td style="white-space: nowrap">http1 stream take 1</td>
    <td style="white-space: nowrap">2.70 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 collect 1mb</td>
    <td style="white-space: nowrap">233.31 KB</td>
    <td>86.31x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 stream take 1</td>
    <td style="white-space: nowrap">1.19 KB</td>
    <td>0.44x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 collect 1mb</td>
    <td style="white-space: nowrap">0.76 KB</td>
    <td>0.28x</td>
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
    <td style="white-space: nowrap">http1 stream take 1</td>
    <td style="white-space: nowrap">317</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 collect 1mb</td>
    <td style="white-space: nowrap">17550.58</td>
    <td>55.36x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 stream take 1</td>
    <td style="white-space: nowrap">61</td>
    <td>0.19x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 collect 1mb</td>
    <td style="white-space: nowrap">33.00</td>
    <td>0.1x</td>
  </tr>
</table>