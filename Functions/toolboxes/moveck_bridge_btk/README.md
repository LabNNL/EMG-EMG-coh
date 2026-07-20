# Moveck Bridge

Bridge proposes to reproduce the API of the Biomechanical-ToolKit (BTK) project as defined in its Matlab bindings and expose it to other programming languages like Python 3.

## Releases

The latest releases are available on the GitHub website. You can find them on the [Releases](https://github.com/moveck-community/moveck_bridge_btk/releases) page.

## Installation

### Matlab

You only need to download the ZIP file corresponding to your operating system and decompress it on the folder of your choice.

Then, you can open Matlab, and add the path of this package to your workspace (see the official documentation for more details: [Change Folders on Search Path](https://www.mathworks.com/help/matlab/matlab_env/add-remove-or-reorder-folders-on-the-search-path.html)).

## Usage/Examples

### Matlab

#### Verification

> [!NOTE]  
> On macOS, the first time you use the package, this may take a few second to get access to the results. This is related to GateKeeper which verifies the content of the package (MEX file, shared libraries and so on). 

A first step to verify the success of the installation is by typing the command `btkGetVersion()` in the [command window](https://www.mathworks.com/help/matlab/ref/commandwindow.html). The result will be a string with the version of the package (e.g., `2024.0.0`).

## Features

### Additions and improvements

- The C3D reader was improved to get Rotation data type (Markerless!) with two new functions `btkGetRotation` and `btkGetRotations`.
- Fix UTF-8 filename issues.
- On a total of 111 functions listed in the original API, less than 10 are not planned to be implemented. Still, if this is a major issue, we will find a way to work on them.

### Current Limitations
By design, some of the original functions are not yet supported. We would like to discuss with the community what should be done.  You can open a [Discussion](https://github.com/moveck-community/moveck_bridge_btk/discussions) for that and explain.

- The functions related to analysis parameters are not yet supported as this information is currently removed from the official documentation of the C3D file format. We want to discuss with the community to determine the needs for those functions (`btkAppendAnalysisParameter`, `btkClearAnalysis`, `btkGetAnalysis`, `btkRemoveAnalysisParameter`).
- Several functions related to the access and modification of events are not implemented because they were too close to the internal C3D structure (`btkGetEventsValues`, `btkSetEventLabel`, `btkSetEventSubject`, `btkSetEventTime`).
- The function `btkRemoveEvent` is not yet implemented.
- `btkCloneAcquisition` and `btkCropAcquisition` are not supported. There is no plan to implement them as we did not receive any feedback on their current usage.
- `btkEmulateC3Dserver` is not available because it was a migration function for c3dserver’s users. Because c3dserver is not supported anymore. This function was not planned to be implemented.
- `btkSetMetaDataLabel` is not yet implemented but is planned for version 2025.2.0.
- `btkTransformTDFToViconC3DFile` is not implemented as we did not receive any feedback on its usage.

### Breaking Changes
During the implementation of the functions and the porting to Python 3, several questions were asked about the way people used the original API and if all the functions should be implemented as-is. Feel free to open a [Discussion](https://github.com/moveck-community/moveck_bridge_btk/discussions) if you think we did some wrong choices or you want improvements.

- The access and modification for residuals' points is not supported. Instead, invalid data is set to NaN (Not a Number) instead of 0 directly in points' values. The functions `btkGetMarkersResiduals`,  `btkSetMarkersResiduals`, `btkGetPointsResiduals`, `btkSetPointResiduals`, and `btkSetPointsResiduals` are not implemented. The parameters (inputs and outputs) of the functions `btkAppendPoint`, `btkGetMarkers`, `btkGetPoint`, and `btkGetPoints` were modified in consequence.
- Metadata description is not supported as well as the lock/unlock feature. Thus, the functions `btkSetMetaDataDescription` and `btkSetMetaDataUnlock` are not implemented.
- All variants of the functions with variadic arguments related to metadata (`btkFindMetaData`, `btkGetMetaData`, `btkRemoveMetaData`, `btkSetMetaData`, `btkSetMetaDataDimensions`, `btkSetMetaDataFormat`) are not implemented. Those variants were not used as the internal storage of the C3D format is only on two levels (group and parameters).

## Documentation

### API Documentation

> [!NOTE]  
> This is a work-in-progress online documentation. We are working on another website which will contain more examples and adapted to work on mobile devices and tablets.

You can get access to the first draft of our [online documentation](https://moveckprodoc.z27.web.core.windows.net/bridge/matlab/nightly/api/main.html) for the Bridge API.

## Contributing

Contributions are always welcome!

> The motivation behind the original project Biomechanical ToolKit was to help the motion analysis community to have an easy way to work together through various and mixed data coming from different acquisition systems. The benefit was, and is still, for lots of users, to create multicentric research, work together on raw data instead of thinking how to aggregate their data. Arnaud Barré, author of the Biomechanical ToolKit project.

Still baked by Arnaud, through Moveck Bridge, this original motivation is still here. The team behind Moveck Bridge proposes to the community to centralize some of their discussions and issues in this repository. This will help to design new features together and help the community.

See  [Contributing.md](https://github.com/moveck-community/moveck_bridge_btk/blob/main/Contributing.md) for ways to get started.

## Support

You can take a look into our contribution [Contributing.md](https://github.com/moveck-community/moveck_bridge_btk/blob/main/Contributing.md) guide for ways to get started.

### Issues

You can use the [Issues](https://github.com/moveck-community/moveck_bridge_btk/issues) page to report a crash, an unexpected behaviour or any improvement requests.

### Discussions

In case you have questions, you want more details on the documentation API or more examples, you can use the [Discussions](https://github.com/moveck-community/moveck_bridge_btk/discussions) page.

## Related

Here are some related projects

[Biomechanical ToolKit](https://github.com/Biomechanical-ToolKit/BTKCore): The original project which is no longer maintained.

## License

See the [License.txt](https://github.com/moveck-community/moveck_bridge_btk/blob/main/License.txt) file available in the repository for more information.