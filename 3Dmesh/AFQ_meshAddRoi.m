function msh = AFQ_meshAddRoi(msh, roiPath, color, dilate, alpha, useDistThresh, useNormals)
% Color mesh vertices based on a region of interest and add to msh obj
%
% msh = AFQ_meshAddRoi(msh, roiPath, color, dilate, alpha, useDistThresh, useNormals)
%
% This function maps an roi to a mesh. See AFQ_meshCreate. ROI should be a
% binary nifti image that coregistered to the mesh. This is done by either
% finding the nearest mesh vertex to each ROI coordinate or by searching
% for mesh vertices that are within a defined distance of the roi.
%
% Inputs:
%
% msh           - AFQ msh structure. See AFQ_meshCreate
% roiPath       - Path to the roi.nii.gz file. A binary image of the roi
% color         - [r g b] value to color the mesh
% dilate        - scaler denoting how many adjacent vertices to expand the roi to
% alpha         - transparency of roi on mesh
% useDistThresh - default to 0. This means we map each roi coord to the
%                 neares mesh vertex. If a scaler is provided then, 
%                 instead, we map the roi to every vertex that is less 
%                 than useDistThresh mm from the roi
% useNormals    - If a distance thresh is supplied than use normals
%                 indicates whether distance should be euclidean or
%                 distance along the normal. binary. default true (1)
%
% Outputs:
%
% msh - msh struct file
%
% Copyright Jason D. Yeatman

if notDefined('useDistThresh')
    useDistThresh = 0;
end
if notDefined('useNormals')
    useNormals = 1;
end
if notDefined('dilate')
    dilate = 0;
end
if notDefined('alpha')
    alpha = 1;
end
% Convert the nifti image to a set of coordinates
if ischar(roiPath)
    roi = dtiRoiFromNifti(roiPath, [],[],'mat',[],false);
    % Remove file extension and path to get the name of the image
    roiIm = readFileNifti(roiPath);
    [~,valname] = fileparts(roiIm.fname);
else
    roi = roiPath;
    valname = roi.name;
end
% Remove a secondary extension from the valname if there is one
valname = prefix(valname);
% remove any characters that are not allowed for field names
rmchar = {' ','_','1','2','3','4','5','6','7','8','9','0'};
for ch = 1:length(rmchar)
    if valname(1)==rmchar{ch}
        valname = horzcat('x',valname);
        continue
    end
end
valname(strfind(valname,' ')) = '_';
valname(strfind(valname,'-')) = '_';

% Map the ROI to the mesh
if useDistThresh == 0
    % Find the closes mesh vertex to each coordinate
    msh_indices = nearpoints(roi.coords', msh.vertex.origin');
else
    % Or find mesh vertices that are closer than useDistThresh to any roi
    % coordinate.
    [roi_indices, bestSqDist] = nearpoints(msh.vertex.origin', roi.coords');
    msh_indices = find(bestSqDist<(useDistThresh^2));
    
    % For vertices within the threshold check if the ROI point lies
    % along the normal or not
    if useNormals == 1
        % Get vertices and normals
        vlist = msh.vertex.origin(msh_indices,:);
        nlist = real(msh.normals.smooth20(bestSqDist<(useDistThresh^2),:));
        % Stack up vertices expanded along the normals
        c=0;
        for dd = 1:useDistThresh
            c = c+1;
            [~, vlist_sqd(c,:)] = nearpoints(vlist'+ dd.*nlist', roi.coords');
        end
        % Now check if these normals intersect the roi coords with a
        % distance of less than 1mm
        norm_indices = any(vlist_sqd <= 1);
        % Remove msh_indices that do not meet this criterion
        msh_indices = msh_indices(norm_indices);
    end
end

% Dilate the roi to neighboring vertices
if dilate > 0
    for ii = 1:dilate
        % Find faces that touch one of the roi indices
        msh_faces = sum(ismember(msh.face.origin, msh_indices),2)>0;
        msh_indicesNew = msh.face.origin(msh_faces,:);
        % Add the vertices connected by this face to the roi
        msh_indices = unique(horzcat(msh_indices, msh_indicesNew(:)'));
    end
end
% Save these indices into a field titled based on the image name
msh.roi.(valname) = msh_indices;
msh.roi.show{end+1} = valname;

% Color current mesh vertices
% First we need to check to see if the vertices are the same as the
% original ones
if  strcmp(msh.map2origin.(msh.vertex.current),'origin')
    % Combine colors
    facecolors = alpha.*repmat(color,length(msh_indices),1) + (1-alpha).*msh.tr.FaceVertexCData(msh_indices,:);
    msh.tr.FaceVertexCData(msh_indices,:) = facecolors;
else
    % Find the vertex to origin mapping
    new_indices = find(ismember(msh.map2origin.(msh.vertex.current), msh_indices));
    facecolors = alpha.*repmat(color,length(new_indices),1) + (1-alpha).*msh.tr.FaceVertexCData(new_indices,:);
    msh.tr.FaceVertexCData(new_indices,:) = facecolors;
end