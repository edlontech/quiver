Benchmark

Benchmark run from 2026-03-04 10:50:07.247679Z UTC

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
    <td style="white-space: nowrap; text-align: right">177.21</td>
    <td style="white-space: nowrap; text-align: right">5.64 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;14.55%</td>
    <td style="white-space: nowrap; text-align: right">5.48 ms</td>
    <td style="white-space: nowrap; text-align: right">8.80 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 collect 1mb</td>
    <td style="white-space: nowrap; text-align: right">165.24</td>
    <td style="white-space: nowrap; text-align: right">6.05 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;16.18%</td>
    <td style="white-space: nowrap; text-align: right">5.87 ms</td>
    <td style="white-space: nowrap; text-align: right">9.15 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 stream take 1</td>
    <td style="white-space: nowrap; text-align: right">93.63</td>
    <td style="white-space: nowrap; text-align: right">10.68 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;12.48%</td>
    <td style="white-space: nowrap; text-align: right">10.31 ms</td>
    <td style="white-space: nowrap; text-align: right">15.51 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 collect 1mb</td>
    <td style="white-space: nowrap; text-align: right">93.02</td>
    <td style="white-space: nowrap; text-align: right">10.75 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;9.97%</td>
    <td style="white-space: nowrap; text-align: right">10.40 ms</td>
    <td style="white-space: nowrap; text-align: right">14.89 ms</td>
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
    <td style="white-space: nowrap;text-align: right">177.21</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 collect 1mb</td>
    <td style="white-space: nowrap; text-align: right">165.24</td>
    <td style="white-space: nowrap; text-align: right">1.07x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 stream take 1</td>
    <td style="white-space: nowrap; text-align: right">93.63</td>
    <td style="white-space: nowrap; text-align: right">1.89x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 collect 1mb</td>
    <td style="white-space: nowrap; text-align: right">93.02</td>
    <td style="white-space: nowrap; text-align: right">1.91x</td>
  </tr>

</table>